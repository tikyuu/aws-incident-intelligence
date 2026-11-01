"""AWS APIはすべてモックし、ネットワークと認証情報を使わずに検証する。"""
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from contextlib import redirect_stdout
from unittest.mock import Mock, patch

from botocore.exceptions import ClientError, ReadTimeoutError

spec = importlib.util.spec_from_file_location(
    "handler", Path(__file__).resolve().parents[1] / "environments/dev/incident/lambda/handler.py",
)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


class LogCollectionTests(unittest.TestCase):
    def setUp(self):
        self.environment = patch.dict(os.environ, {
            "NGINX_LOG_GROUP_ARN": "arn:aws:logs:ap-northeast-1:123456789012:log-group:/aii/dev/ecs/nginx",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.event = {
            "id": "event-1", "time": "2026-10-30T12:00:00Z",
            "detail": {"taskArn": "arn:aws:ecs:ap-northeast-1:123456789012:task/aii-dev/" + "a" * 32},
        }
        self.client = Mock()

    def page(self, events=(), token="end"):
        return {"events": list(events), "nextBackwardToken": token}

    def test_success_and_empty_page_pagination(self):
        self.client.get_log_events.side_effect = [
            self.page(token="one"),
            self.page([{"timestamp": 2, "message": "nginx error"}], "two"),
            self.page(token="two"),
        ]
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertEqual(result["status"], "collected")
        self.assertFalse(result["truncated"])
        request = self.client.get_log_events.call_args_list[0].kwargs
        self.assertEqual(request["logStreamName"], "ecs/nginx/" + "a" * 32)
        self.assertEqual(request["endTime"] - request["startTime"], 900001)
        self.assertFalse(request["startFromHead"])

    def test_stop_time_preferred_over_event_time(self):
        self.event["detail"]["stoppedAt"] = "2026-10-30T11:59:00Z"
        self.client.get_log_events.return_value = self.page()
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertEqual(result["end_time"], 1793361540001)

    def test_latest_events_and_character_limit(self):
        self.client.get_log_events.return_value = self.page([
            {"timestamp": 1, "message": "older"},
            {"timestamp": 2, "message": "x" * 25000},
        ])
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertTrue(result["truncated"])
        self.assertEqual(result["events"], [{"timestamp": 2, "message": "x" * 20000}])
        self.assertEqual(self.client.get_log_events.call_count, 1)

    def test_event_limit(self):
        self.client.get_log_events.return_value = self.page([
            {"timestamp": n, "message": "line"} for n in range(100)
        ])
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertEqual(len(result["events"]), 100)
        self.assertTrue(result["truncated"])

    def test_page_limit(self):
        self.client.get_log_events.side_effect = [self.page(token=str(n)) for n in range(3)]
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertTrue(result["truncated"])
        self.assertEqual(self.client.get_log_events.call_count, 3)

    def test_empty_logs(self):
        self.client.get_log_events.return_value = self.page()
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertEqual(result["status"], "unavailable")
        self.assertEqual(result["reason"], "no_logs_available_yet_or_in_time_window")

    def test_api_errors_and_partial_evidence(self):
        for code in ("ResourceNotFoundException", "AccessDeniedException"):
            with self.subTest(code=code):
                self.client.get_log_events.side_effect = ClientError(
                    {"Error": {"Code": code, "Message": "private"}}, "GetLogEvents",
                )
                result = handler.collect_nginx_logs(self.event, self.client)
                self.assertEqual(result["reason"], code)
                self.assertEqual(result["status"], "unavailable")
        self.client.get_log_events.side_effect = [
            self.page([{"timestamp": 1, "message": "evidence"}]),
            ReadTimeoutError(endpoint_url="https://logs.example"),
        ]
        result = handler.collect_nginx_logs(self.event, self.client)
        self.assertEqual(result["status"], "partial")
        self.assertEqual(len(result["events"]), 1)

    def test_invalid_input_does_not_call_api(self):
        for event, reason in [
            ({"detail": {}}, "invalid_task_arn"),
            ({**self.event, "time": "invalid"}, "invalid_stop_time"),
            ({**self.event, "time": "2026-10-30T12:00:00"}, "invalid_stop_time"),
        ]:
            with self.subTest(reason=reason):
                self.assertEqual(handler.collect_nginx_logs(event, self.client)["reason"], reason)
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(handler.collect_nginx_logs(self.event, self.client)["reason"],
                             "missing_log_group_configuration")
        self.client.get_log_events.assert_not_called()

class AlarmReceptionTests(unittest.TestCase):
    def test_receives_alarm_without_collecting_logs_or_printing_entire_event(self):
        event = {
            "alarmData": {
                "alarmName": "aii-dev-ecs-memory-high",
                "state": {"value": "ALARM", "reason": "PRIVATE_DETAIL"},
                "configuration": {
                    "metrics": [{
                        "metricStat": {
                            "metric": {
                                "namespace": "AWS/ECS",
                                "name": "MemoryUtilization",
                                "dimensions": {
                                    "ClusterName": "aii-dev-ecs-cluster",
                                    "ServiceName": "aii-dev-ecs-service-nginx",
                                },
                            },
                            "period": 60,
                            "stat": "Average",
                        },
                    }],
                },
            },
        }
        output = io.StringIO()
        with (
            patch.dict(os.environ, {"AGENT_RUNTIME_ARN": "arn:aws:bedrock-agentcore:ap-northeast-1:123456789012:runtime/test-agent"}),
            patch.object(handler, "collect_nginx_logs") as collect,
            redirect_stdout(output),
        ):
            result = handler.lambda_handler(event, None)
        collect.assert_not_called()
        record = json.loads(output.getvalue())
        self.assertEqual(record["alarm_name"], "aii-dev-ecs-memory-high")
        self.assertEqual(record["state"], "ALARM")
        self.assertEqual(record["cluster_name"], "aii-dev-ecs-cluster")
        self.assertEqual(record["service_name"], "aii-dev-ecs-service-nginx")
        self.assertEqual(result["cluster_name"], record["cluster_name"])
        self.assertEqual(result["service_name"], record["service_name"])
        self.assertNotIn("PRIVATE_DETAIL", output.getvalue())
        self.assertEqual(result["status"], "received")


if __name__ == "__main__":
    unittest.main()
