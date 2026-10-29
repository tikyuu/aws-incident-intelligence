terraform {
  required_version = "~> 1.16.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Stateはこのディレクトリに保存する。Gitには含めない。
  backend "local" {
    path = "terraform.tfstate"
  }
}
