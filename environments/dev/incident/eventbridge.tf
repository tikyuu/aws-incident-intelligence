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

  # Lambdaのターゲットと呼び出し許可は、Lambda実装時に追加する。
}
