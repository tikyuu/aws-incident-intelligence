resource "aws_ecs_service" "nginx" {
  name            = "aii-dev-ecs-service-nginx"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.nginx.arn
  launch_type     = "FARGATE"

  enable_execute_command = true

  # 検証を一時停止中。再開時に1へ戻してタスクを起動する。
  desired_count = 0

  # 更新時は新しいタスクを起動してから古いタスクを停止する。
  # 通常は1個だが、入れ替え中は最大2個になる。
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [var.public_subnet_id]
    security_groups  = [aws_security_group.nginx.id]
    assign_public_ip = true
  }

  # タスクを起動する前にHTTPSの送信を許可する。
  depends_on = [aws_vpc_security_group_egress_rule.nginx_https]
}
