# AWS Incident Intelligence

ECSのメモリ使用率が高い状態をCloudWatch Alarmで検知し、生成AIによる調査レポートを残す検証用プロジェクト。

**現在はネットワーク・ECSクラスター・単発Nginxタスク定義・Security Group・ECSとLambdaのログ・IAM権限・停止イベント受信用Lambda・Nginxログ取得処理を作成済み。旧構成のEventBridge停止検知ルール・ターゲット・Lambda呼び出し許可は削除済み。ECSサービス・メモリアラーム・アラームからLambdaへの直接呼び出し・メトリクス収集・Bedrock連携・S3は未実装。Lambdaはまだ停止イベント形式の処理であり、現在は自動起動する経路がない。AWSへの構築は未実施。** 設計と手順は、まずこのREADMEに集約する。

## 最初の完成条件

ECSサービスのメモリ使用率が高い状態が続いたらCloudWatch Alarmで検知し、Lambdaがメモリの推移と関連ログを収集してBedrockへ渡し、原因候補・根拠・追加の確認事項を含むJSON・MarkdownのレポートをS3に保存できること。タスクが停止する前でも調査を開始する。

基本の流れは「ECSサービス → CloudWatchのメモリメトリクス → CloudWatch Alarm → Lambda → Bedrock → S3」。関連ログはCloudWatch LogsからLambdaが取得する。

ECSサービスで検証用タスクを1個動かす方針。メモリはまずサービス単位の`AWS/ECS`の`MemoryUtilization`を監視する。しきい値・統計・評価期間・欠損データの扱い、メモリ使用量を意図的に増やす検証方法は、一つずつ説明してから決める。Nginx単体への通信で十分なメモリ増加が起きるとは限らないため、検証用アプリや負荷生成方法も検討する。

CloudWatch Alarmの`ALARM`状態への遷移時のアクションにLambdaを設定する。Lambda側には対象アラームARNとアカウントに限定した呼び出し許可を定義する。直接呼び出しでは停止イベントと通知形式が異なるため、ハンドラーも対応させる。ALARMが継続している間に定期実行する設計ではない。[AWS公式の直接呼び出し仕様](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-actions-Lambda.html)に従う。

高いメモリ使用率だけで、停止の予兆やメモリリークと断定しない。レポートでは観測した事実と原因候補を分け、ログやメトリクスで確認できないことは不足として記録する。

現在のコードは単発タスクと停止イベントを前提としており、ECSサービス・メモリアラーム・アラームからLambdaへの直接呼び出し設定と許可・メトリクス収集・アラーム対象からタスクとログを特定する処理は未実装。旧構成の停止検知ルール・ターゲット・Lambda呼び出し許可と、不要になったincident側の`ecs_cluster_arn`入力変数は削除済み。ログ収集は流用できる部分を活用する。起動失敗の分析は最初の完成条件から外す。

ユーザーはメモリ監視を優先し、必要なコストを許容する方針。AWS構築前には、具体的な構成の概算費用と停止・削除手順を確認する。コスト許容の表明をAWSへの構築実行の承認とは扱わない。

## 構成と役割

![AWS Incident Intelligenceの完成予定アーキテクチャ](docs/architecture.png)

[draw.ioで編集するファイル](docs/architecture.drawio)をダウンロードし、draw.ioで開けます。図は旧来の停止イベント中心の構成です。メモリアラームを起点とする構成への更新は今後行います。

アイコンは[AWS公式配布ページ](https://aws.amazon.com/architecture/icons/)で2026年10月29日に確認した現行版（2026年7月31日版）を使用しています。

| サービス・道具 | 担当 |
| --- | --- |
| ECS Fargate | ECSサービスで監視対象のコンテナを実行する |
| EventBridge | 今回は使用しない。旧構成の停止検知用定義は削除済み |
| CloudWatch | メモリメトリクスを監視し、アラームからLambdaを直接呼び出す。CloudWatch Logsで関連ログを保管する |
| Lambda | アラーム対象の特定、証拠収集、Bedrockへの依頼、結果の保存を行う |
| Bedrock | 渡された証拠から原因候補と対応方法を生成する |
| S3 | 障害ごとのレポートをファイルとして残す |
| Terraform | 上記のAWSリソースをコードで作成・削除する |

分析処理はECS上で動かさず、Lambdaに分離する。最初はDynamoDBやAIエージェントを追加しない。

## アラームを起点とする呼び出し

指定したメモリアラームが`ALARM`状態へ変わったときにLambdaを直接呼び出す設計。重複配信・再発・回復時の扱いは、アラームと受信処理の実装時に決める。

従来のEventBridgeによるタスク停止検知ルール、Lambdaターゲット、EventBridgeからの呼び出し許可は削除済み。CloudWatch Alarm本体とCloudWatchからの呼び出し許可は、対象アラームの定義と合わせて追加する。

既存のPython処理は停止イベント向けのログ収集として残しているが、そのままではアラーム通知を扱えない。今後、アラーム形式の受信と対象サービスのタスク特定に対応させる。

## 分析に渡す情報とレポート

Lambdaはアラーム名・状態変化の時刻・判定条件・対象クラスターとサービス、メモリ使用率の時系列、関連するタスクとログを収集する設計とする。現在のハンドラーは停止イベント専用のため、アラームの受信と対象タスクの特定、メトリクス取得、必要なIAM権限を今後追加する。

メモリ使用率の推移を最初の完成条件に含める。CPUなど追加の情報をどこまで収集するかは別途決める。取得失敗時には不足と理由を明示し、メモリの値だけで原因を断定しない。

- ログの時間範囲・件数・文字数を制限し、認証情報などを除外してからBedrockへ送る。
- ログやイベントは信頼できない入力として扱い、内部の指示文に従わせない。
- BedrockのモデルIDまたは推論プロファイルと、呼び出し先リージョンを設定で変更可能にする。
- レポートは「概要・確認できた事実・原因候補と根拠・追加調査項目・推奨対応」を分ける。
- インシデントID、発生時刻、対象リソース、使用モデル、トークン使用量も記録する。
- ログ取得失敗時は不足を明示する。Bedrock失敗時も、収集済み証拠と失敗理由をLambdaからS3へ残す。

## Nginxログ収集（現在の実装）

`incident/lambda/handler.py`はタスクARNからIDを取り出し、`ecs/nginx/<タスクID>`を読み取る。`detail.stoppedAt`（なければイベントの`time`）を基準に直前15分を検索し、停止時刻ちょうどのログも含める。

- 新しいログを優先し、最大100件・本文合計20,000文字・API呼び出し3回で打ち切る。返すログは時系列順に並べる。上限到達時は`truncated`を記録するため、全件取得を保証しない。
- 空ページでも継続トークンが変わる間は、上限内で後方ページングする。[GetLogEventsの仕様](https://docs.aws.amazon.com/boto3/latest/reference/services/logs/client/get_log_events.html)に従う。
- ログ未到着・範囲内のログなし・ストリーム未作成・権限不足・通信エラーは理由を記録する。途中の取得失敗では、収集済みログも保持する。
- SDKの接続・読み取りタイムアウトは各1秒、自動リトライなし。配信遅延に対する待機・再取得は未実装であり、実環境での確認と再取得設計は今後の課題。
- ログ本文は実行ログに出さない。本文中の機密情報の除外は未実装で、Bedrock連携前に追加する。現時点では収集のみで、分類・分析・永続保存は行わない。

ローカル検証（AWS接続なし）:

```sh
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
terraform fmt -check -recursive
terraform -chdir=environments/dev/incident validate
```

## 検証環境の方針

- dev環境のみ。Terraformは`network`・`ecs`・`incident`の3つに実行ディレクトリ・Stateを分け、最初は子モジュールを作らない。
- 1 AZ・Public Subnet 1つ。ALB・NAT Gatewayは作成しない。
- ECSサービスでタスク1個を継続稼働させてメモリを監視する方針（未実装）。検証を終える際のサービス停止・削除手順も整備する。インバウンド通信は禁止する。
- タスク用Security GroupはECS側で管理し、`vpc_id`入力変数で作成先を指定する。受信ルールは作成せず、送信は`0.0.0.0/0`宛てのTCP 443（HTTPS）のみ許可する。
- NginxはLinux / X86_64のFargateタスクで、CPU 0.25 vCPU・メモリ512 MiBとする。現在の単発タスク定義は公式イメージ`nginx:1.30.6`を指定している。ECSサービスは今後追加し、メモリ増加を再現するためのアプリ・構成は別途決める。
- Nginxのログは`/aii/dev/ecs/nginx`に保存し、保存期間を3日とする。
- ログストリーム名は`ecs/nginx/<タスクID>`。ログ送信は`non-blocking`・バッファ10 MiBとし、バッファ超過時はログが欠落し得る。
- タスク実行用IAMロールは、Nginx用ロググループ内のログストリーム作成・ログ送信のみを許可する。
- イメージ取得などに必要な通信は、Public IPとInternet Gateway経由で確保する。
- Lambdaは初期構成ではVPCに接続しない。
- Lambda関数名は`aii-dev-incident`。Python 3.14・arm64・メモリ128 MiB・タイムアウト10秒で定義し、実行ログ用グループ`/aws/lambda/aii-dev-incident`（保存期間3日）と実行ロールを接続する。現段階はイベントID・タスクARN・終了コードとログ取得の概要を実行ログに出す。ログ本文は出力せず、後続の分析処理向けにハンドラーの戻り値へ含める。環境変数などが含まれ得るイベント全体は出力せず、正常・異常の分類もまだ行わない。
- Lambda実行ロールは`aii-dev-incident-lambda-execution`。自身のロググループ内のログストリーム作成・ログ送信と、`nginx_log_group_arn`で受け取ったロググループ内のログ読み取り（`logs:GetLogEvents`）を許可する。ロググループはTerraformで作成するため、Lambdaにロググループ作成権限は付けない。Bedrock呼び出し・S3保存は、対象リソースの定義に合わせて権限を追加する。ECSのログストリーム名はタスクIDから組み立てる想定とし、一覧取得・検索の権限は付けない。ログ取得のPython処理を追加済み。環境変数`NGINX_LOG_GROUP_ARN`へ同じARNを渡し、読み取り権限の設定後にLambdaを作成する。
- IAMは最小権限。S3はパブリックアクセスを禁止し、暗号化する。
- 認証情報・Terraform State・機密値はGitに含めない。

命名は`aii-環境-用途`を基本とする（例：`aii-dev-vpc`）。`aii`はAWS Incident Intelligenceの略称。共通タグは`Project = aii`、`Environment = dev`、`ManagedBy = Terraform`に統一する。S3など名前の一意性が必要なリソースには識別子を追加する。

## Terraformのファイル構成

以下は予定構成。現在は`network/`と`ecs/`の初期設定、ネットワーク・ECSクラスター・ログ・実行権限・正常系タスク定義を作成済み。他のディレクトリ・ファイルは必要になった段階で追加し、構成が固まってからモジュール化を検討する。

```text
environments/dev/
├── network/            # VPC・Subnet・通信経路
│   ├── versions.tf     # バージョン条件・ローカルState設定（作成済み）
│   ├── providers.tf    # AWS Provider・共通タグ（作成済み）
│   ├── .terraform.lock.hcl # Providerの使用バージョン（作成済み）
│   └── network.tf      # VPC・Subnet・Internet Gateway・ルート設定
├── ecs/                # ECSクラスター・ログ・実行権限・正常系タスク定義・Security Group
└── incident/           # Lambda・ログ・IAM・停止イベント向けログ取得処理を作成済み。アラーム・直接呼び出し・メトリクス収集・Bedrock・S3は今後追加
```

各ディレクトリにProvider・バージョン設定を置き、個別にinit・plan・applyする。同じディレクトリの`.tf`ファイルはまとめて読み込まれるが、隣のディレクトリは自動では読み込まれない。CloudWatch LogsとIAMは、利用するECS・Lambda側で管理する。

`incident/lambda/handler.py`がLambdaの処理本体。Archive Providerで`incident/build/incident-lambda.zip`にまとめ、コードのハッシュで変更を検知する。`build/`はGit管理対象外。ZIPはplan時に生成されるため、保存したplanをapplyする際はZIPも保持する。

ネットワーク、検証タスク、障害分析という変更目的で分ける。`incident/`内は`cloudwatch.tf`・`lambda.tf`・`s3.tf`などに整理し、分析機能としてまとめて管理する。

Stateは各ディレクトリの`terraform.tfstate`にローカル保存する（例：`environments/dev/network/terraform.tfstate`）。Gitには含めず、AWS構築後は変更・削除に備えて保管する。各ディレクトリの`.terraform.lock.hcl`はGit管理する。

ディレクトリ間で必要なSubnet ID・ARNなどは、作成元のoutputから利用側の入力へ渡す。具体的な受け渡し方法は実装時に決める。作成は依存先から、削除は利用側から行う。Stateを分けるため、全体の実行順序はTerraformが自動調整しない。

ECS側の`nginx_log_group_arn`出力と、incident側の同名の入力変数を定義済み。ECS側の出力値をincident側の入力へ渡す。変数を定義しただけでは自動接続されず、具体的な受け渡し手順は今後追加する。Lambda実行ロールの読み取りポリシーは、この入力変数を対象ARNとして参照する。

全体の構築順は`network` → `ecs` → `incident`、削除順はその逆とする。後からモジュール化する際は、既存Stateを維持し、`moved`ブロックなどでリソースのアドレス変更に対応する。

初期版はNginx公式イメージを利用するため、専用のECRリポジトリは作成しない。

## 進め方

1. この設計を確認する。
2. ECSサービス → メモリ監視・CloudWatch AlarmからLambdaへの直接呼び出し → Lambdaの証拠収集 → Bedrock → S3の順に、一つずつ説明してコードを作成する。
3. Terraformのfmt / validate、Pythonの単体テストでローカル検証する。
4. リソース一覧・概算費用・State管理・削除手順を確認する。
5. 承認後にAWSへ構築し、通常時・継続したメモリ使用率の上昇によるアラーム・回復・重複配信・ログやメトリクスの取得失敗・Bedrock失敗を検証する。

**各段階の内容を説明し、了承を得てから次に進む。課金・リソース変更を伴うAWS操作は事前確認を必須とする。**

## 初期版の対象外

フロントエンド、独自Web API、メール・Slack通知、自動復旧、GitHub Actions、起動失敗・停止イベントを起点としたAI分析、応答遅延・HTTPエラーを起点とした検知。

## 参考：AWS公式

- [ECSタスク状態変更イベント](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_task_events.html)
- [LambdaとBedrockでCloudWatchログを分析する実装例](https://aws.amazon.com/blogs/mt/using-generative-ai-to-gain-insights-into-cloudwatch-logs/)（今回と同一構成ではない）
- [Converse API](https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html)
