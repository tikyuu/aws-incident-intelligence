resource "aws_sns_topic" "investigations" {
  name = "aii-dev-sns-investigations"
}

resource "aws_sns_topic_policy" "investigations" {
  arn = aws_sns_topic.investigations.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "aiops.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.investigations.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.investigations.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
