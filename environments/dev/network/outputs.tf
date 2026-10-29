output "vpc_id" {
  description = "ECS用Security Groupを作成するVPCのID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Fargateタスクを起動するPublic SubnetのID"
  value       = aws_subnet.public.id
}
