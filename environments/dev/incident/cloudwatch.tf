resource "aws_cloudwatch_log_group" "lambda" {
  # Lambda関数名はaii-dev-incidentを予定。関数側でもこのロググループを使用する。
  name              = "/aws/lambda/aii-dev-incident"
  retention_in_days = 3
}
