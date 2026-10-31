output "cluster_arn" {
  description = "監視対象のECSクラスターARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "メモリメトリクスの監視対象となるECSクラスター名"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "メモリメトリクスの監視対象となるECSサービス名"
  value       = aws_ecs_service.nginx.name
}

output "nginx_log_group_arn" {
  description = "Lambdaのログ読み取り権限の対象となるNginx用ロググループARN"
  value       = aws_cloudwatch_log_group.nginx.arn
}
