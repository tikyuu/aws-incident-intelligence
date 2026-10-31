variable "vpc_id" {
  description = "ECS用Security Groupを作成するVPCのID"
  type        = string
}

variable "public_subnet_id" {
  description = "network側のpublic_subnet_id出力から渡す、タスク配置先のPublic Subnet ID"
  type        = string
}
