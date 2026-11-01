resource "aws_bedrockagentcore_harness" "incident" {
  harness_name       = "aii_dev_bedrock_agent"
  execution_role_arn = aws_iam_role.bedrock_agent_execution.arn

  model {
    bedrock_model_config {
      model_id   = "global.openai.gpt-6.1-sol"
      api_format = "converse_stream"
    }
  }

  system_prompt {
    text = file("${path.module}/agent/instructions.txt")
  }

  memory {
    disabled {}
  }

  max_iterations  = 10
  max_tokens      = 8192
  timeout_seconds = 300
}

# 移行中：Lambdaの呼び出し先をharnessへ切り替えた後に削除する。
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
