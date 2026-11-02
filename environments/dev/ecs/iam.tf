resource "aws_iam_role" "task" {
  name = "aii-dev-ecs-task"

  # ECS Execの接続用エージェントが使うロール。
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# タスク用ロール：ECS Execのコマンドと実行結果を送受信する。
resource "aws_iam_role_policy" "task_ecs_exec" {
  name = "aii-dev-ecs-exec-channels"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "task_execution" {
  name = "aii-dev-ecs-task-execution"

  # ECS・Fargateがタスクの実行に使うロール。
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# タスク実行ロール：Nginx用ECRからイメージを取得する。
resource "aws_iam_role_policy" "task_execution_ecr" {
  name = "aii-dev-ecs-pull-nginx-image"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = aws_ecr_repository.nginx.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "task_execution_logs" {
  name = "aii-dev-ecs-write-nginx-logs"
  role = aws_iam_role.task_execution.id

  # ロググループはTerraformで作成するため、作成権限は不要。
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.nginx.arn}:log-stream:*"
    }]
  })
}
