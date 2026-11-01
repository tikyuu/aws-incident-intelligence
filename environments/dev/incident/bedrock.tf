resource "aws_bedrockagentcore_harness" "incident" {
  harness_name       = "aii_dev_bedrock_agent"
  execution_role_arn = aws_iam_role.bedrock_agent_execution.arn

  environment_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.bedrock_agent.repository_url}:v1"
    }
  }

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

  depends_on = [aws_iam_role_policy.bedrock_agent_ecr]
}
