# リージョン・認証情報はAWS CLIの設定や環境変数から取得する。
provider "aws" {
  default_tags {
    tags = {
      Project     = "aws-incident-intelligence"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
