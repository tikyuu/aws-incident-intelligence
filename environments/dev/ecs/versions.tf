terraform {
  required_version = "~> 1.16.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ECS用のStateをこのディレクトリに保存する。
  backend "local" {
    path = "terraform.tfstate"
  }
}
