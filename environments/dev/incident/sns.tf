resource "aws_sns_topic" "incident" {
  name = "aii-dev-sns-incident"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.incident.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
