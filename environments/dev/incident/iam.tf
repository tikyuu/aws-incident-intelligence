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

  # 操作権限は対象リソースの定義時に追加する。
  # Lambda自身のログ送信・ECSログの読み取り・Bedrock呼び出し・S3保存を想定。
}
