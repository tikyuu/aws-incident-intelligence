resource "aws_ecs_cluster" "main" {
  name = "aii-dev-cluster"

  # 初期版は低コストを優先し、Container Insightsを無効にする。
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}
