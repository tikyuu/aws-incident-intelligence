output "cluster_arn" {
  description = "停止イベントを検知する対象のECSクラスターARN"
  value       = aws_ecs_cluster.main.arn
}
