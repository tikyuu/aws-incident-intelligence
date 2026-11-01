resource "aws_ecr_repository" "bedrock_agent" {
  name                 = "aii-dev-ecr-bedrock-agent"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
