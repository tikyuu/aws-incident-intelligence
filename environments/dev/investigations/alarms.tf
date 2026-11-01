resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name        = "aii-dev-investigations-ecs-memory-high"
  alarm_description = "ECS service average memory utilization exceeds 80% for one minute"

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"
  dimensions = {
    ClusterName = "aii-dev-ecs-cluster"
    ServiceName = "aii-dev-ecs-service-nginx"
  }

  statistic           = "Average"
  period              = 60
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "missing"

  alarm_actions             = [awscc_aiops_investigation_group.investigations.arn]
  ok_actions                = []
  insufficient_data_actions = []
  actions_enabled           = true
}
