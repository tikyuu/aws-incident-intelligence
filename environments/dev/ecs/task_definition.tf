resource "aws_ecs_task_definition" "nginx" {
  family                   = "aii-dev-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "${aws_ecr_repository.nginx.repository_url}:v1"
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

  # 必要な権限を付けてからタスク定義を登録する。
  depends_on = [
    aws_iam_role_policy.task_execution_logs,
    aws_iam_role_policy.task_execution_ecr,
    aws_iam_role_policy.task_ecs_exec,
    aws_iam_role_policy.task_ecs_exec_logs,
  ]
}
