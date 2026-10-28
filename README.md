# AWS Incident Intelligence

ECSタスクの異常停止を検知し、生成AIによる調査レポートを残す検証用プロジェクト。

**現在は設計のみ。コード作成・AWSへの構築は未実施。** 設計と手順は、まずこのREADMEに集約する。

## 最初の完成条件

Nginxの設定を意図的に間違えてECSタスクを異常停止させ、停止情報とログをBedrockで分析し、JSON・MarkdownのレポートをS3に保存できること。

## 構成と役割

```text
ECS Fargate（Nginx）── ログ ──→ CloudWatch Logs
        │
        ↓ タスク停止イベント
EventBridge（対象クラスターのSTOPPEDのみ）
        │
        ↓
Lambda ── 停止情報・ログを収集 ← ECS / CloudWatch
        │
        ├─ 必要な情報を送信 → Bedrock（Converse API）
        │                  ← 原因候補・根拠・対応方法
        │
        └─ レポートを保存 → S3（JSON / Markdown）
```

| サービス・道具 | 担当 |
| --- | --- |
| ECS Fargate | 検証対象のNginxコンテナを実行する |
| EventBridge | タスク停止イベントを受け取り、Lambdaを起動する |
| CloudWatch | ログを保管する。取得可能なメトリクスも調査材料にする |
| Lambda | 停止の分類、証拠収集、Bedrockへの依頼、結果の保存を行う |
| Bedrock | 渡された証拠から原因候補と対応方法を生成する |
| S3 | 障害ごとのレポートをファイルとして残す |
| Terraform | 上記のAWSリソースをコードで作成・削除する |

分析処理はECS上で動かさず、Lambdaに分離する。最初はDynamoDBやAIエージェントを追加しない。

## 正常停止と異常停止

EventBridgeは停止を検知し、Lambdaが停止理由・終了コード・タスクの用途を組み合わせて分類する。

| ケース | 扱い |
| --- | --- |
| 意図した手動停止・通常のサービス停止 | 異常として分析しない |
| 正常終了する検証タスク | 異常として分析しない |
| Nginxの設定エラーによる異常終了 | Bedrockによる分析の対象 |
| 情報が足りず分類できない停止 | 判定保留として記録する |

終了コードだけで正常・異常や原因を断定しない。同じ停止イベントが再配信される前提で、重複を識別し、再実行時の扱いを実装時に決める。

## 分析に渡す情報とレポート

Lambdaは発生時刻、タスクARN、停止理由、コンテナ終了コード、関連ログを収集する。CPU・メモリは取得可能な場合に添付し、取得できない情報は理由付きで「取得不可」とする。

単発タスクのCPU・メモリ取得には追加の監視設計が必要なため、最初の完成条件には含めない。

- ログの時間範囲・件数・文字数を制限し、認証情報などを除外してからBedrockへ送る。
- ログやイベントは信頼できない入力として扱い、内部の指示文に従わせない。
- BedrockのモデルIDまたは推論プロファイルと、呼び出し先リージョンを設定で変更可能にする。
- レポートは「概要・確認できた事実・原因候補と根拠・追加調査項目・推奨対応」を分ける。
- インシデントID、発生時刻、対象リソース、使用モデル、トークン使用量も記録する。
- ログ取得失敗時は不足を明示する。Bedrock失敗時も、収集済み証拠と失敗理由をLambdaからS3へ残す。

## 検証環境の方針

- dev環境のみ。Terraformは`environments/dev`と`modules`を分け、モジュール数は必要最小限にする。
- 1 AZ・Public Subnet 1つ。ALB・NAT Gatewayは作成しない。
- タスクは検証時だけ起動する。インバウンド通信は禁止する。
- イメージ取得などに必要な通信は、Public IPとInternet Gateway経由で確保する。
- Lambdaは初期構成ではVPCに接続しない。
- IAMは最小権限。S3はパブリックアクセスを禁止し、暗号化する。
- 認証情報・Terraform State・機密値はGitに含めない。

## 進め方

1. この設計を確認する。
2. ECS基盤 → EventBridge → Lambda → Bedrock → S3の順にコードを作成する。
3. Terraformのfmt / validate、Pythonの単体テストでローカル検証する。
4. リソース一覧・概算費用・State管理・削除手順を確認する。
5. 承認後にAWSへ構築し、正常停止・異常停止・重複・ログ取得失敗・Bedrock失敗を検証する。

**各段階の内容を説明し、了承を得てから次に進む。課金・リソース変更を伴うAWS操作は事前確認を必須とする。**

## 初期版の対象外

フロントエンド、独自Web API、メール・Slack通知、自動復旧、GitHub Actions、停止を伴わない応答遅延・HTTPエラーの検知。

## 参考：AWS公式

- [ECSタスク状態変更イベント](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html)
- [LambdaとBedrockでCloudWatchログを分析する実装例](https://aws.amazon.com/blogs/mt/using-generative-ai-to-gain-insights-into-cloudwatch-logs/)（今回と同一構成ではない）
- [Converse API](https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html)
