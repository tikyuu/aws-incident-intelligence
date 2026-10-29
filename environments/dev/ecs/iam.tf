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
