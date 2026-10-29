resource "aws_security_group" "nginx" {
  name        = "aii-dev-ecs-sg"
  description = "Security group for the Nginx verification task"
  vpc_id      = var.vpc_id

  # 受信ルールは作成しない。外部からNginxへの接続は許可しない。
  tags = {
    Name = "aii-dev-ecs-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "nginx_https" {
  security_group_id = aws_security_group.nginx.id
  description       = "HTTPS for container image pulls and CloudWatch Logs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
