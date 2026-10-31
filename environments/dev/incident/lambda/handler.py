"""ECS停止イベントの受信とNginxログ収集。分類と分析は今後追加する。"""

import json
import os
import re
from datetime import datetime, timedelta

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
    detail = event.get("detail", {})
    logs = collect_nginx_logs(event)
    # 環境変数を含み得るイベント全体・ログ本文は出力しない。
    record = {
        "message": "ECS task event received",
        "event_id": event.get("id"),
        "event_time": event.get("time"),
        "task_arn": detail.get("taskArn"),
        "cluster_arn": detail.get("clusterArn"),
        "last_status": detail.get("lastStatus"),
        "stop_code": detail.get("stopCode"),
        "containers": [
            {"name": container.get("name"), "exit_code": container.get("exitCode")}
            for container in detail.get("containers", [])
        ],
        "log_collection": {key: value for key, value in logs.items() if key != "events"},
        "log_event_count": len(logs["events"]),
    }
    print(json.dumps(record, ensure_ascii=False))
    # 本文は将来の分析処理へ渡すために返す。機密情報の除外はBedrock連携時に実装する。
    return {"status": "received", "event_id": event.get("id"), "logs": logs}
