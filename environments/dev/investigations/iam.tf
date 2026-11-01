data "aws_caller_identity" "current" {}

resource "aws_iam_role" "investigations" {
  name = "aii-dev-cloudwatch-investigations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "aiops.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:aiops:ap-northeast-1:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}
