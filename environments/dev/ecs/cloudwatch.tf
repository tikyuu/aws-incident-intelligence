resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/aii/dev/ecs/nginx"
  retention_in_days = 3
}
