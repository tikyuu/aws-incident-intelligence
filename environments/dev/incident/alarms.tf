resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name        = "aii-dev-ecs-memory-high"
  alarm_description = "ECS service average memory utilization exceeds 80% for one minute"

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  statistic           = "Average"
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  # データがないことを正常・異常と決めつけない。
  treat_missing_data = "missing"

  alarm_actions             = [aws_lambda_function.incident.arn]
  ok_actions                = []
  insufficient_data_actions = []

  # ALARMへの遷移時にLambdaへ調査を依頼する。
  actions_enabled = true
}
