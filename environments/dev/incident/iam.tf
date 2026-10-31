resource "aws_iam_role" "lambda_execution" {
  name = "aii-dev-incident-lambda-execution"

  # 障害分析用Lambdaが、このロールを引き受けることを許可する。
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # Bedrock呼び出し・S3保存の権限は今後追加する。
}

resource "aws_iam_role_policy" "lambda_execution_logs" {
  name = "aii-dev-incident-lambda-write-logs"
  role = aws_iam_role.lambda_execution.id

  # ロググループはTerraformで作成するため、作成権限は不要。
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      # Lambda自身のロググループ内のストリームだけに書き込みを許可する。
      Resource = "${aws_cloudwatch_log_group.lambda.arn}:log-stream:*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_read_nginx_logs" {
  name = "aii-dev-incident-lambda-read-nginx-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:GetLogEvents"]
      # ECS側から渡されたロググループ内のストリームだけを読み取る。
      Resource = "${var.nginx_log_group_arn}:log-stream:*"
    }]
  })
}
