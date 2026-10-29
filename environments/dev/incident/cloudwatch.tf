resource "aws_cloudwatch_log_group" "lambda" {
  # Lambda関数側のlogging_configで、このロググループを指定する。
  name              = "/aws/lambda/aii-dev-incident"
  retention_in_days = 3
}
