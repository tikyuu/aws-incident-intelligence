variable "ecs_cluster_arn" {
  description = "停止イベントを検知する対象のECSクラスターARN"
  type        = string
}

variable "nginx_log_group_arn" {
  description = "ECS側のnginx_log_group_arn出力から渡す、ログ読み取り権限の対象ARN"
  type        = string
}
