"""ECS停止イベントの受信確認。正常・異常の分類と分析は今後追加する。"""

import json


def lambda_handler(event, context):
    detail = event.get("detail", {})

    # 環境変数などが含まれ得るため、イベント全体はログに出さない。
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
    }
    print(json.dumps(record, ensure_ascii=False))

    # 受信済みという意味。正常停止・異常停止の判定結果ではない。
    return {"status": "received", "event_id": event.get("id")}
