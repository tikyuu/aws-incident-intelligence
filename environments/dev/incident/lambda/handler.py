"""CloudWatch Alarmの通知を受け取り、ハーネスへ調査を依頼する。"""

import json
import os
import re
from datetime import datetime, timedelta
from uuid import uuid4

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

MAX_EVENTS = 100
MAX_CHARACTERS = 20_000
MAX_PAGES = 3


def collect_nginx_logs(event, client=None):
    """停止前15分のログを取得する。本文は実行ログへ出さない。"""
    result = {"status": "unavailable", "events": [], "truncated": False}
    detail = event.get("detail", {})
    task_arn = detail.get("taskArn", "")
    match = re.fullmatch(
        r"arn:[^:]+:ecs:[^:]+:\d{12}:task/(?:[^/]+/)?([0-9a-f]{32})",
        task_arn if isinstance(task_arn, str) else "",
    )
    if not match:
        return {**result, "reason": "invalid_task_arn"}
    group = os.environ.get("NGINX_LOG_GROUP_ARN")
    if not group:
        return {**result, "reason": "missing_log_group_configuration"}
    try:
        stopped_at = datetime.fromisoformat(detail.get("stoppedAt") or event["time"])
        if stopped_at.tzinfo is None:
            raise ValueError("timezone required")
        end = int(stopped_at.timestamp() * 1000) + 1
        start = max(0, int((stopped_at - timedelta(minutes=15)).timestamp() * 1000))
    except (KeyError, TypeError, ValueError, OverflowError):
        return {**result, "reason": "invalid_stop_time"}

    result.update(log_stream=f"ecs/nginx/{match[1]}", start_time=start, end_time=end)
    request = {
        "logGroupIdentifier": group,
        "logStreamName": result["log_stream"],
        "startTime": start,
        "endTime": end,
        "startFromHead": False,
    }
    characters = 0
    try:
        if client is None:
            client = boto3.client("logs", config=Config(
                connect_timeout=1, read_timeout=1,
                retries={"total_max_attempts": 1},
            ))
        for _ in range(MAX_PAGES):
            response = client.get_log_events(
                **request, limit=MAX_EVENTS - len(result["events"]),
            )
            # 各ページ内は時系列順。後方ページングなので新しい行から予算を使う。
            for entry in reversed(response["events"]):
                message = entry["message"]
                remaining = MAX_CHARACTERS - characters
                result["events"].append({
                    "timestamp": entry["timestamp"], "message": message[:remaining],
                })
                characters += min(len(message), remaining)
                if len(message) > remaining or characters >= MAX_CHARACTERS or len(result["events"]) >= MAX_EVENTS:
                    result["truncated"] = True
                    break
            if result["truncated"]:
                break
            token = response["nextBackwardToken"]
            if token == request.get("nextToken"):
                break
            request["nextToken"] = token
        else:
            result["truncated"] = True
        result["status"] = "collected" if result["events"] else "unavailable"
        if not result["events"]:
            result["reason"] = "no_logs_available_yet_or_in_time_window"
    except (ClientError, BotoCoreError) as exc:
        # エラーメッセージ全文は記録しない。収集済みの証拠は残す。
        result["status"] = "partial" if result["events"] else "unavailable"
        result["reason"] = (
            exc.response["Error"]["Code"] if isinstance(exc, ClientError)
            else type(exc).__name__
        )
        result["truncated"] = bool(result["events"])
    result["events"].sort(key=lambda entry: entry["timestamp"])
    return result


def lambda_handler(event, context):
    harness_arn = os.environ["HARNESS_ARN"]
    alarm = event["alarmData"]

    alarm_name = alarm["alarmName"]
    state = alarm["state"]["value"]
    alarm_time = alarm["state"]["timestamp"]

    # 今回のアラームは、ECSのメモリメトリクス1つを監視する。
    metric = alarm["configuration"]["metrics"][0]["metricStat"]["metric"]
    dimensions = metric["dimensions"]
    cluster_name = dimensions["ClusterName"]
    service_name = dimensions["ServiceName"]

    investigation_request = {
        "instruction": "このアラームの原因候補と対策を調査してください。",
        "alarm_name": alarm_name,
        "alarm_time": alarm_time,
        "cluster_name": cluster_name,
        "service_name": service_name,
    }

    # 通知全体ではなく、受信確認に必要な項目だけを記録する。
    print(json.dumps({
        "message": "CloudWatch alarm received",
        "alarm_name": alarm_name,
        "state": state,
        "cluster_name": cluster_name,
        "service_name": service_name,
    }, ensure_ascii=False))

    client = boto3.client("bedrock-agentcore", region_name="ap-northeast-1", config=Config(
        connect_timeout=3, read_timeout=330,
        retries={"total_max_attempts": 1},
    ))
    try:
        response = client.invoke_harness(
            harnessArn=harness_arn,
            runtimeSessionId=str(uuid4()),
            messages=[{
                "role": "user",
                "content": [{"text": json.dumps(investigation_request, ensure_ascii=False)}],
            }],
        )
        stream = response["stream"]
        stop_reason = None
        try:
            # 調査内容の本文はログへ出さず、最後まで応答を受け取る。
            for event in stream:
                if any(key in event for key in (
                    "runtimeClientError", "internalServerException", "validationException",
                )):
                    raise RuntimeError("Harness execution failed")
                if "messageStop" in event:
                    stop_reason = event["messageStop"]["stopReason"]
        finally:
            stream.close()
        if stop_reason != "end_turn":
            raise RuntimeError("Harness investigation did not complete")
    except (ClientError, BotoCoreError, RuntimeError) as exc:
        print(json.dumps({
            "message": "Harness investigation failed",
            "alarm_name": alarm_name,
            "error_type": type(exc).__name__,
        }, ensure_ascii=False))
        raise

    return {
        "status": "completed",
        "alarm_name": alarm_name,
        "state": state,
        "cluster_name": cluster_name,
        "service_name": service_name,
        "investigation_request": investigation_request,
    }
