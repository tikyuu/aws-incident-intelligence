resource "awscc_aiops_investigation_group" "investigations" {
  name                                 = "aii-dev-investigations"
  role_arn                             = aws_iam_role.investigations.arn
  is_cloud_trail_event_history_enabled = false

  chatbot_notification_channels = [{
    sns_topic_arn = aws_sns_topic.investigations.arn
  }]

  depends_on = [
    aws_iam_role_policy.investigations_metrics,
    aws_iam_role_policy.investigations_logs,
    aws_iam_role_policy.investigations_ecs,
    aws_sns_topic_policy.investigations,
  ]
}
