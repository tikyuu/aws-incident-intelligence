provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Project     = "aii"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

provider "awscc" {
  region = "ap-northeast-1"
}
