# AWS Incident Intelligence

ECSのメモリ使用率が高い状態をCloudWatch Alarmで検知し、生成AIによる調査レポートを残す検証用プロジェクト。

**現在はネットワーク・ECSクラスター・Nginxタスク定義・ECSサービス・Security Group・ECSとLambdaのログ・IAM権限・アラーム受信確認用Lambda・停止イベント向けのNginxログ取得関数を作成済み。旧構成のEventBridge停止検知ルール・ターゲット・Lambda呼び出し許可は削除済み。メモリアラームとCloudWatchからのLambda呼び出し許可も定義済み。Lambdaはアラーム名・状態・クラスター名・サービス名を記録する受信確認まで実装済み。アラームの呼び出しアクションは無効のまま。メトリクス収集・アラームからのログ取得・Bedrock連携・S3は未実装。AWSへの構築は未実施。** 設計と手順は、まずこのREADMEに集約する。

## 最初の完成条件

ECSサービスのメモリ使用率が高い状態が続いたらCloudWatch Alarmで検知し、Lambdaがメモリの推移と関連ログを収集してBedrockへ渡し、原因候補・根拠・追加の確認事項を含むJSON・MarkdownのレポートをS3に保存できること。タスクが停止する前でも調査を開始する。

基本の流れは「ECSサービス → CloudWatchのメモリメトリクス → CloudWatch Alarm → Lambda → Bedrock → S3」。関連ログはCloudWatch LogsからLambdaが取得する。

ECSサービスで検証用タスクを1個動かす方針。クラスター名は`aii-dev-ecs-cluster`、サービス名は`aii-dev-ecs-service-nginx`とする。メモリはまずサービス単位の`AWS/ECS`の`MemoryUtilization`を監視する。条件は1分間の平均が80%を超えた場合に1回で発報、欠損データはデータ不足とする。メモリ使用量を意図的に増やす検証方法は別途整備する。Nginx単体への通信で十分なメモリ増加が起きるとは限らないため、検証用アプリや負荷生成方法も検討する。

CloudWatch Alarmの`ALARM`状態への遷移時のアクションにLambdaを設定する。Lambda側には対象アラームARNとアカウントに限定した呼び出し許可を定義する。ハンドラーは直接呼び出しの`alarmData`からアラーム名・状態・対象クラスター名・サービス名を読み取る。ALARMが継続している間に定期実行する設計ではない。[AWS公式の直接呼び出し仕様](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarms-and-actions-Lambda.html)に従う。

高いメモリ使用率だけで、停止の予兆やメモリリークと断定しない。レポートでは観測した事実と原因候補を分け、ログやメトリクスで確認できないことは不足として記録する。

ECSサービスのTerraform定義は作成済み。Lambdaはアラームの受信確認に対応済み。メモリアラームと直接呼び出し設定・許可は定義済みだが、呼び出しアクションは無効。メトリクス収集・アラーム対象からタスクとログを特定する処理は未実装。旧構成の停止検知ルール・ターゲット・Lambda呼び出し許可と、不要になったincident側の`ecs_cluster_arn`入力変数は削除済み。ログ収集は流用できる部分を活用する。起動失敗の分析は最初の完成条件から外す。

ユーザーはメモリ監視を優先し、必要なコストを許容する方針。AWS構築前には、具体的な構成の概算費用と停止・削除手順を確認する。コスト許容の表明をAWSへの構築実行の承認とは扱わない。

## 構成と役割

現在は構成の比較検証を計画している段階です。まずCloudWatch investigationsによる専用AI調査とメール通知を試し、その結果を確認してからBedrock版を検証します。S3への調査結果保存は今回の比較案から外します。以下の旧案は比較用に残しており、採用決定を意味しません。Terraform・Pythonには、まだ比較案の変更を反映していません。

![比較案A：CloudWatchの専用AI調査とメール通知](docs/architecture-investigations.png)

[比較案AのSVG](docs/architecture-investigations.svg)もあります。[draw.ioファイル](docs/architecture.drawio)には、先頭に「① CloudWatch案」、2枚目に既存の「② Bedrock旧案」を配置しています。シートはdraw.io画面下部のタブで切り替えます。図にはサービスと処理の流れを中心に表示し、詳細な検証項目はこのREADMEに記載しています。

比較案Aは「メモリアラーム → CloudWatch investigations → SNSの調査更新通知 → Lambdaで整形 → 別のSNS通知先からメール配信」です。SNSは通知を届けるサービスです。専用調査機能から通知を受け取って処理する方式は[AWS公式ブログ](https://aws.amazon.com/blogs/mt/reimagine-aiops-with-amazon-cloudwatch-investigations-and-amazon-nova-sonic/)と[公式サンプル](https://github.com/aws-samples/sample-intelligent-ops/blob/main/cf-template.yml)を参考にしています。調査更新に含まれる情報が、希望するメール項目を満たすかは未検証です。

AWS上のテストは未実施です。AWS構築前に利用料金と停止・削除手順を確認し、検証は次の順に進めます。

1. 調査対象への権限を読み取りに限定し、検証用ECSサービスで既知のメモリ負荷を発生させ、80%超過によるアラームから調査が自動開始されることを確認する。
2. 専用調査機能の通知データを確認し、検知内容・根拠となるログやメトリクス・原因候補・対策案の有無を記録する。原因を特定できなければ、その旨をメールに明記する。通知データだけでは項目を満たせない場合は、不足を記録し、推測で補完して実装完了としない。
3. 後で設定する宛先へメールを送信できることを確認し、調査更新と、原因候補の承認を伴う正式な事後レポートを区別する。重複通知、調査や配信の失敗時の動作も確認する。
4. 検知から通知までの時間・通知件数・データ取得量・利用料金を記録する。その後、負荷条件・対象サービス・調査対象時間帯を揃えてBedrock版と比較する。Bedrock版のモデルや実行方式は、比較案Aの結果を確認してから決める。

専用調査機能には[関連API等の利用料金](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/investigations-costs.html)が発生する場合があります。ECSの調査品質を高めるために[Container Insightsの有効化が推奨](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Investigations-Services.html)されていますが、現在は無効です。有効化の要否と追加費用は構築前に確認します。

以下は保存している旧案です。

![メモリアラームからAI調査とレポート保存までの完成予定構成](docs/architecture.png)

[draw.ioで編集するファイル](docs/architecture.drawio)・[拡大表示用SVG](docs/architecture.svg)もあります。「② Bedrock旧案」は、既存設計のサービスと役割を簡略化して表示しています。東京の調査処理と米国東部のモデル呼び出し先を分け、観測経路を実線、計画中の調査・保存経路を点線で示しています。詳細な設定値や実装状況の表示は省略しており、AWS上での動作は未検証です。旧案のS3は比較用に残していますが、今回先に試す「① CloudWatch案」にはS3保存を含めません。

CloudWatchは1つの枠にまとめ、その中にAlarmとLogs / Metricsを表示しています。AgentCore Runtimeはエージェントを動かす場所、AgentCore Gatewayは調査APIへの窓口として、箱の見出しで区別しています。

アイコンは[AWS公式配布ページ](https://aws.amazon.com/architecture/icons/)で2026年10月31日に確認した現行版（2026年7月31日版）を使用しています。RuntimeとGatewayには、共通のAgentCoreサービスアイコンを使用しています。

| サービス・道具 | 担当 |
| --- | --- |
| ECS Fargate | ECSサービスで監視対象のコンテナを実行する |
| EventBridge | 今回は使用しない。旧構成の停止検知用定義は削除済み |
| CloudWatch | メモリメトリクスを監視し、アラームからLambdaを直接呼び出す。CloudWatch Logsで関連ログを保管する |
| Lambda | アラーム対象の特定、証拠収集、Bedrockへの依頼、結果の保存を行う |
| Bedrock | 渡された証拠から原因候補と対応方法を生成する |
| S3 | 障害ごとのレポートをファイルとして残す |
| Terraform | 上記のAWSリソースをコードで作成・削除する |

監視対象のECSタスクとは別に調査エージェントを動かす。Lambdaをアラーム通知の入口とし、エージェントに調査を依頼する。エージェントのAgentCore Runtimeと実行用ロールのTerraform定義は作成済みだが、実行権限とプログラムは未実装。DynamoDBは初期構成に追加しない。

## アラームを起点とする呼び出し

指定したメモリアラームが`ALARM`状態へ変わったときにLambdaを直接呼び出す設計。重複配信・再発・回復時の扱いは、アラームと受信処理の実装時に決める。

従来のEventBridgeによるタスク停止検知ルール、Lambdaターゲット、EventBridgeからの呼び出し許可は削除済み。CloudWatch Alarm本体を`incident/alarms.tf`、CloudWatchからの呼び出し許可を`incident/lambda.tf`に定義済み。対象のアラームARNとアカウントで許可範囲を限定する。

メモリアラーム`aii-dev-ecs-memory-high`は次の条件で定義済み。

| 項目 | 設定 |
| --- | --- |
| メトリクス | `AWS/ECS`の`MemoryUtilization` |
| 監視対象 | 入力変数`ecs_cluster_name`・`ecs_service_name`で指定 |
| 集計 | `Average`、60秒 |
| しきい値 | `GreaterThanThreshold`、80（80%ちょうどは超過に含めない） |
| 発報 | 評価期間1、超過データポイント1 |
| 欠損 | `missing`。評価対象がすべて欠損したら`INSUFFICIENT_DATA` |
| 呼び出し | `ALARM`への遷移時にLambda。回復・データ不足時のアクションはなし |

メトリクスの到着・評価タイミングにより、負荷を与えてから正確に60秒後に検知するとは限らない。アラームがALARMのままでも繰り返し呼び出す設計ではない。

**現在は`actions_enabled = false`**。AWSへ構築した場合、アラームの評価は行われるがLambdaは呼び出されない。受信確認後、調査処理の接続・検証に進む段階で有効化する。

`lambda_handler`は`event["alarmData"]`から`alarmName`と`state.value`を取り出す。さらに`configuration.metrics[0].metricStat.metric.dimensions`から`ClusterName`と`ServiceName`を読み、必要な項目だけをJSONで実行ログに記録する。今回定義した単一メトリクスのアラームを対象とし、複合アラームやメトリクス数式は扱わない。通知全体は出力しない。現在は受信確認のみで、状態による分岐・AWS APIの呼び出し・証拠収集・分析は行わない。必須キーが欠けた通知は例外となり、受信成功とは扱わない。

以前の`collect_nginx_logs`関数は停止イベント向けのまま残しているが、現在のハンドラーからは呼び出さない。今後、アラーム対象サービスのタスクを特定し、稼働中のタスクのログ取得に対応させる。

## 分析に渡す情報とレポート

Lambdaはアラーム名・状態変化の時刻・判定条件・対象クラスターとサービス、メモリ使用率の時系列、関連するタスクとログを収集する設計とする。現在のハンドラーはアラーム名・状態・対象クラスター名・サービス名の受信確認のみ。発生時刻・対象タスクの特定・メトリクス取得・必要なIAM権限を今後追加する。

メモリ使用率の推移を最初の完成条件に含める。CPUなど追加の情報をどこまで収集するかは別途決める。取得失敗時には不足と理由を明示し、メモリの値だけで原因を断定しない。

- ログの時間範囲・件数・文字数を制限し、認証情報などを除外してからBedrockへ送る。
- ログやイベントは信頼できない入力として扱い、内部の指示文に従わせない。
- BedrockのモデルIDと呼び出し先リージョンは、1環境用の固定値としてTerraformに直接記述し、実行プログラムへ環境変数で渡す。
- レポートは「概要・確認できた事実・原因候補と根拠・追加調査項目・推奨対応」を分ける。
- インシデントID、発生時刻、対象リソース、使用モデル、トークン使用量も記録する。
- ログ取得失敗時は不足を明示する。Bedrock失敗時も、収集済み証拠と失敗理由をLambdaからS3へ残す。

## Nginxログ収集（既存関数。現在のハンドラーからは未接続）

`incident/lambda/handler.py`はタスクARNからIDを取り出し、`ecs/nginx/<タスクID>`を読み取る。`detail.stoppedAt`（なければイベントの`time`）を基準に直前15分を検索し、停止時刻ちょうどのログも含める。

- 新しいログを優先し、最大100件・本文合計20,000文字・API呼び出し3回で打ち切る。返すログは時系列順に並べる。上限到達時は`truncated`を記録するため、全件取得を保証しない。
- 空ページでも継続トークンが変わる間は、上限内で後方ページングする。[GetLogEventsの仕様](https://docs.aws.amazon.com/boto3/latest/reference/services/logs/client/get_log_events.html)に従う。
- ログ未到着・範囲内のログなし・ストリーム未作成・権限不足・通信エラーは理由を記録する。途中の取得失敗では、収集済みログも保持する。
- SDKの接続・読み取りタイムアウトは各1秒、自動リトライなし。配信遅延に対する待機・再取得は未実装であり、実環境での確認と再取得設計は今後の課題。
- ログ本文は実行ログに出さない。本文中の機密情報の除外は未実装で、Bedrock連携前に追加する。この関数を単独で呼んだ場合の収集処理であり、アラーム受信からは未接続。分類・分析・永続保存は行わない。

ローカル検証（AWS接続なし）:

```sh
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
terraform fmt -check -recursive
terraform -chdir=environments/dev/ecs validate
terraform -chdir=environments/dev/incident validate
```

## 検証環境の方針

- dev環境のみ。Terraformは`network`・`ecs`・`incident`の3つに実行ディレクトリ・Stateを分け、最初は子モジュールを作らない。
- 1 AZ・Public Subnet 1つ。ALB・NAT Gatewayは作成しない。
- ECSサービス`aii-dev-ecs-service-nginx`の定義を作成済み。既存クラスター`aii-dev-ecs-cluster`とNginxタスク定義を参照し、Fargateで`desired_count = 1`を維持する。更新時の最小稼働率100%・最大200%とし、入れ替え中は最大2個が動く。オートスケーリング・ALBは追加しない。検証を終える際のサービス停止・削除手順は今後整備する。インバウンド通信は禁止する。
- タスク用Security GroupはECS側で管理し、`vpc_id`入力変数で作成先を指定する。受信ルールは作成せず、送信は`0.0.0.0/0`宛てのTCP 443（HTTPS）のみ許可する。
- NginxはLinux / X86_64のFargateタスクで、CPU 0.25 vCPU・メモリ512 MiBとする。タスク定義は公式イメージ`nginx:1.30.6`を指定し、ECSサービスから参照する。メモリ増加を再現するためのアプリ・構成は別途決める。
- Nginxのログは`/aii/dev/ecs/nginx`に保存し、保存期間を3日とする。
- ログストリーム名は`ecs/nginx/<タスクID>`。ログ送信は`non-blocking`・バッファ10 MiBとし、バッファ超過時はログが欠落し得る。
- タスク実行用IAMロールは、Nginx用ロググループ内のログストリーム作成・ログ送信のみを許可する。
- イメージ取得などに必要な通信は、Public IPとInternet Gateway経由で確保する。
- Lambdaは初期構成ではVPCに接続しない。
- Lambda関数名は`aii-dev-incident`。Python 3.14・arm64・メモリ128 MiB・タイムアウト10秒で定義し、実行ログ用グループ`/aws/lambda/aii-dev-incident`（保存期間3日）と実行ロールを接続する。現段階はアラーム名・状態・対象クラスター名・サービス名を実行ログに記録し、受信確認の結果を返す。通知全体は出力せず、ログ・メトリクス収集と分析もまだ行わない。
- Lambda実行ロールは`aii-dev-incident-lambda-execution`。自身のロググループ内のログストリーム作成・ログ送信と、`nginx_log_group_arn`で受け取ったロググループ内のログ読み取り（`logs:GetLogEvents`）を許可する。ロググループはTerraformで作成するため、Lambdaにロググループ作成権限は付けない。Bedrock呼び出し・S3保存は、対象リソースの定義に合わせて権限を追加する。ECSのログストリーム名はタスクIDから組み立てる想定とし、一覧取得・検索の権限は付けない。ログ取得のPython処理を追加済み。環境変数`NGINX_LOG_GROUP_ARN`へ同じARNを渡し、読み取り権限の設定後にLambdaを作成する。
- IAMは最小権限。S3はパブリックアクセスを禁止し、暗号化する。
- 認証情報・Terraform State・機密値はGitに含めない。

命名は`aii-環境-用途`を基本とする（例：`aii-dev-vpc`）。`aii`はAWS Incident Intelligenceの略称。共通タグは`Project = aii`、`Environment = dev`、`ManagedBy = Terraform`に統一する。S3など名前の一意性が必要なリソースには識別子を追加する。

## Terraformのファイル構成

以下は予定構成。現在は`network/`と`ecs/`の初期設定、ネットワーク・ECSクラスター・ログ・実行権限・正常系タスク定義・ECSサービスを作成済み。他のディレクトリ・ファイルは必要になった段階で追加し、構成が固まってからモジュール化を検討する。

```text
environments/dev/
├── network/            # VPC・Subnet・通信経路
│   ├── versions.tf     # バージョン条件・ローカルState設定（作成済み）
│   ├── providers.tf    # AWS Provider・共通タグ（作成済み）
│   ├── .terraform.lock.hcl # Providerの使用バージョン（作成済み）
│   └── network.tf      # VPC・Subnet・Internet Gateway・ルート設定
├── ecs/                # ECSクラスター・サービス・ログ・実行権限・タスク定義・Security Group
└── incident/           # Lambda・ログ・IAM・停止イベント向けログ取得処理を作成済み。アラームと呼び出し許可は定義済み（アクション無効）。受信確認は実装済み。メトリクス収集・ログ取得の接続・Bedrock・S3は今後追加
```

各ディレクトリにProvider・バージョン設定を置き、個別にinit・plan・applyする。同じディレクトリの`.tf`ファイルはまとめて読み込まれるが、隣のディレクトリは自動では読み込まれない。CloudWatch LogsとIAMは、利用するECS・Lambda側で管理する。

`incident/lambda/handler.py`がLambdaの処理本体。Archive Providerで`incident/build/incident-lambda.zip`にまとめ、コードのハッシュで変更を検知する。`build/`はGit管理対象外。ZIPはplan時に生成されるため、保存したplanをapplyする際はZIPも保持する。

ネットワーク、検証タスク、障害分析という変更目的で分ける。`incident/`内は`cloudwatch.tf`・`lambda.tf`・`bedrock.tf`・`s3.tf`などに整理し、分析機能としてまとめて管理する。

`incident/bedrock.tf`に`aws_bedrockagentcore_agent_runtime.incident`を定義済み。1環境で進めるため、名前・モデル・接続先は`bedrock.tf`へ直接記述する。dev/prod用の変数ファイルは追加しない。リソース間の接続に必要な入力・参照は残す。AgentCoreの命名制約に合わせ、名前は`aii_dev_bedrock_agent`とする。採用モデルはGPT-6.1 Sol（`openai.gpt-6.1-sol`）、モデルの呼び出し先はBedrock Mantleの`us-east-1`を初期設定とする。AgentCore自体は既存Providerの東京リージョンに定義する。[AWS公式モデル資料](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-openai-gpt-6-1-sol.html)で提供状況を確認済みだが、利用アカウントでのアクセス可否は未確認。

`iam.tf`に実行用ロール`aii-dev-bedrock-agent-execution`を定義し、`bedrock.tf`から直接参照する。現在は同一アカウント・東京リージョンのAgentCore Runtimeにロールの引き受けを許可する信頼ポリシーのみで、モデル呼び出し・イメージ取得・ログ送信・調査用の権限は未付与。`bedrock_agent_image_uri`はデフォルト値のない必須入力。ECRイメージ・調査プログラムも未実装で、applyの準備は未完了。プログラムはAgentCoreの実行要件に対応し、`MODEL_ID`と`BEDROCK_REGION`を読んでモデルを呼ぶ必要がある。環境変数を指定するだけでAIが動くわけではない。Runtimeのネットワークは`PUBLIC`で、JWT認証を設定せずIAM認証を使用する。LambdaからRuntimeを呼ぶ権限・処理も今後追加する。

旧方式の`aws_bedrockagent_agent`は使わない。[Agents Classicは新規利用の受付を終了](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-classic-maintenance-mode.html)しているため、AgentCore Runtimeを採用する。

入口のLambdaがアラーム情報を渡して調査を依頼し、エージェントが必要に応じて取得用ツールを呼ぶ方式とする。指示文だけで変更操作を禁止するのではなく、取得用ツールとそのIAM権限にも設定変更・再起動・停止の機能を与えない。調査結果では、確認できた事実・根拠・不明点と、優先順位を付けた対策案・想定効果・影響・確認方法を日本語でまとめる。調査ツールは既存のAWS連携機能やMCPを優先して確認し、不足する場合のみ自作を検討する。現在のコンテナ方式のRuntime定義をそのまま使用するか、管理されたエージェント実行方式へ変更するかは、その確認後に決める。

Stateは各ディレクトリの`terraform.tfstate`にローカル保存する（例：`environments/dev/network/terraform.tfstate`）。Gitには含めず、AWS構築後は変更・削除に備えて保管する。各ディレクトリの`.terraform.lock.hcl`はGit管理する。

ディレクトリ間で必要なSubnet ID・ARNなどは、作成元のoutputから利用側の入力へ渡す。具体的な受け渡し方法は実装時に決める。作成は依存先から、削除は利用側から行う。Stateを分けるため、全体の実行順序はTerraformが自動調整しない。

network側の`vpc_id`・`public_subnet_id`出力を、ecs側の同名の入力変数へ渡す。サービスはPublic Subnetにタスクを配置し、Public IPを付与して既存Security Groupを使う。ECS側の`cluster_name`・`service_name`出力をincident側の`ecs_cluster_name`・`ecs_service_name`入力へ渡し、メモリアラームの対象指定に利用する。いずれもディレクトリ間で自動接続はされない。

ECS側の`nginx_log_group_arn`出力と、incident側の同名の入力変数を定義済み。ECS側の出力値をincident側の入力へ渡す。変数を定義しただけでは自動接続されず、具体的な受け渡し手順は今後追加する。Lambda実行ロールの読み取りポリシーは、この入力変数を対象ARNとして参照する。

全体の構築順は`network` → `ecs` → `incident`、削除順はその逆とする。後からモジュール化する際は、既存Stateを維持し、`moved`ブロックなどでリソースのアドレス変更に対応する。

初期版はNginx公式イメージを利用するため、監視対象のNginx専用のECRリポジトリは作成しない。調査エージェント用のECRリポジトリとイメージは今後整備する。

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
