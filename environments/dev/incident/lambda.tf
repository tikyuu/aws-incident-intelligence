data "archive_file" "incident_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/build/incident-lambda.zip"
}

resource "aws_lambda_function" "incident" {
  function_name = "aii-dev-incident"
  description   = "Log received ECS task stopped events"
  role          = aws_iam_role.lambda_execution.arn
  runtime       = "python3.14"
  handler       = "handler.lambda_handler"
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.incident_lambda.output_path
  source_code_hash = data.archive_file.incident_lambda.output_base64sha256

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  # ログ送信権限を付けてから関数を作成する。
  # ロググループの作成順序はlogging_configの参照で保証する。
  depends_on = [aws_iam_role_policy.lambda_execution_logs]
}
