resource "aws_cloudwatch_log_group" "lambda" {
  # Lambda関数側のlogging_configで、このロググループを指定する。
  name              = "/aws/lambda/aii-dev-incident"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "bedrock_agent" {
  name              = "/aws/bedrock-agentcore/runtimes/${aws_bedrockagentcore_harness.incident.environment_actual[0].agentcore_runtime_environment[0].agent_runtime_id}-DEFAULT"
  retention_in_days = 7
}
