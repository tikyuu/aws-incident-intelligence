# 認証情報はAWS CLIの設定や環境変数から取得する。
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
