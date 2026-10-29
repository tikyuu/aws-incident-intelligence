resource "aws_ecs_task_definition" "nginx" {
  family                   = "aii-dev-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Nginx自身はAWS APIを使わないため、task_role_arnは設定しない。
  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:1.30.6"
      essential = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "ecs"
          mode                  = "non-blocking"
          max-buffer-size       = "10m"
        }
      }
    }
  ])

  # ロールにログ送信権限を付けてからタスク定義を登録する。
  depends_on = [aws_iam_role_policy.task_execution_logs]
}
