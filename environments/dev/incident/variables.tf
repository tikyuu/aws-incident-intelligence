variable "nginx_log_group_arn" {
  description = "ECS側のnginx_log_group_arn出力から渡す、ログ読み取り権限の対象ARN"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS側のcluster_name出力から渡す、メモリ監視対象のクラスター名"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS側のservice_name出力から渡す、メモリ監視対象のサービス名"
  type        = string
}

variable "bedrock_agent_image_uri" {
  description = "AgentCore用の実行プログラムを含むECRコンテナイメージのURI"
  type        = string
}

variable "budget_notification_email" {
  description = "月額予算の通知先メールアドレス"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "調査結果の送信先メールアドレス"
  type        = string
  sensitive   = true
}
