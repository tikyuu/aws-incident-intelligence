resource "aws_cloudwatch_event_rule" "ecs_task_stopped" {
  name           = "aii-dev-ecs-task-stopped"
  description    = "Detect stopped tasks in the verification ECS cluster"
  event_bus_name = "default"

  # 正常停止も含めて拾い、正常・異常の分類は後でLambdaで行う。
  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Task State Change"]
    detail = {
      clusterArn = [var.ecs_cluster_arn]
      lastStatus = ["STOPPED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "incident_lambda" {
  rule           = aws_cloudwatch_event_rule.ecs_task_stopped.name
  event_bus_name = aws_cloudwatch_event_rule.ecs_task_stopped.event_bus_name
  target_id      = "incident-lambda"
  arn            = aws_lambda_function.incident.arn

  # 呼び出し許可を設定してから送信先を登録する。
  depends_on = [aws_lambda_permission.eventbridge]
}
