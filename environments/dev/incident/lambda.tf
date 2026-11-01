data "archive_file" "incident_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/build/incident-lambda.zip"
}

resource "aws_lambda_function" "incident" {
  function_name = "aii-dev-incident"
  description   = "Send CloudWatch alarm investigation requests to AgentCore harness"
  role          = aws_iam_role.lambda_execution.arn
  runtime       = "python3.14"
  handler       = "handler.lambda_handler"
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 360

  filename         = data.archive_file.incident_lambda.output_path
  source_code_hash = data.archive_file.incident_lambda.output_base64sha256

  environment {
    variables = {
      HARNESS_ARN         = aws_bedrockagentcore_harness.incident.arn
      NGINX_LOG_GROUP_ARN = var.nginx_log_group_arn
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  # ログ送信・ハーネス呼び出し権限を付けてから関数を作成する。
  # ロググループの作成順序はlogging_configの参照で保証する。
  depends_on = [
    aws_iam_role_policy.lambda_execution_logs,
    aws_iam_role_policy.lambda_invoke_harness,
    aws_iam_role_policy.lambda_read_nginx_logs,
    aws_iam_role_policy.bedrock_agent_execution_logs,
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "memory_alarm" {
  statement_id  = "AllowExecutionFromEcsMemoryAlarm"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"

  # このアカウントの、今回作るメモリアラームだけに許可する。
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}
