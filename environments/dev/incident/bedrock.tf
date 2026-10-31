resource "aws_bedrockagentcore_agent_runtime" "incident" {
  agent_runtime_name = "aii_dev_bedrock_agent"
  role_arn           = aws_iam_role.bedrock_agent_execution.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.bedrock_agent_image_uri
    }
  }

  environment_variables = {
    MODEL_ID       = "openai.gpt-6.1-sol"
    BEDROCK_REGION = "us-east-1"
  }

  network_configuration {
    network_mode = "PUBLIC"
  }
}
