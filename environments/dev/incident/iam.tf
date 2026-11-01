resource "aws_iam_role" "bedrock_agent_execution" {
  name = "aii-dev-bedrock-agent-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = [
            "arn:aws:bedrock-agentcore:ap-northeast-1:${data.aws_caller_identity.current.account_id}:runtime/*",
            "arn:aws:bedrock-agentcore:ap-northeast-1:${data.aws_caller_identity.current.account_id}:harness/*",
          ]
        }
      }
    }]
  })
}

# ハーネス実行ロール：指定したグローバル推論でSolを呼び出す
resource "aws_iam_role_policy" "bedrock_agent_inference" {
  name = "aii-dev-bedrock-agent-inference"
  role = aws_iam_role.bedrock_agent_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.current.account_id}:inference-profile/global.openai.gpt-6.1-sol"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:*::foundation-model/openai.gpt-6.1-sol"
        Condition = {
          ArnEquals = {
            "bedrock:InferenceProfileArn" = "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.current.account_id}:inference-profile/global.openai.gpt-6.1-sol"
          }
        }
      },
    ]
  })
}

# Runtime実行ロール：東京のメトリクスを読む
resource "aws_iam_role_policy" "bedrock_agent_metrics" {
  name = "aii-dev-bedrock-agent-read-metrics"
  role = aws_iam_role.bedrock_agent_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:RequestedRegion" = "ap-northeast-1"
        }
      }
    }]
  })
}

# Runtime実行ロール：Nginxのログを検索する
resource "aws_iam_role_policy" "bedrock_agent_logs" {
  name = "aii-dev-bedrock-agent-read-nginx-logs"
  role = aws_iam_role.bedrock_agent_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:FilterLogEvents",
        ]
        Resource = "${var.nginx_log_group_arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:StopQuery",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      },
    ]
  })
}

# Runtime実行ロール：ECSの構成・状態を読む
resource "aws_iam_role_policy" "bedrock_agent_ecs" {
  name = "aii-dev-bedrock-agent-read-ecs"
  role = aws_iam_role.bedrock_agent_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
        ]
        Resource = [
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}",
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}",
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:task/${var.ecs_cluster_name}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListServices",
          "ecs:ListTasks",
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:cluster/${var.ecs_cluster_name}"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "ap-northeast-1"
          }
        }
      },
    ]
  })
}

# Runtime実行ロール：調査結果をSNSへ送る
resource "aws_iam_role_policy" "bedrock_agent_notifications" {
  name = "aii-dev-bedrock-agent-publish-notifications"
  role = aws_iam_role.bedrock_agent_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.incident.arn
    }]
  })
}

resource "aws_iam_role" "lambda_execution" {
  name = "aii-dev-incident-lambda-execution"

  # 障害分析用Lambdaが、このロールを引き受けることを許可する。
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

}

# Lambda実行ロール：今回のハーネスへ調査を依頼する
resource "aws_iam_role_policy" "lambda_invoke_harness" {
  name = "aii-dev-incident-lambda-invoke-harness"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock-agentcore:InvokeHarness",
        "bedrock-agentcore:InvokeAgentRuntime",
      ]
      Resource = aws_bedrockagentcore_harness.incident.arn
    }]
  })
}

resource "aws_iam_role_policy" "lambda_execution_logs" {
  name = "aii-dev-incident-lambda-write-logs"
  role = aws_iam_role.lambda_execution.id

  # ロググループはTerraformで作成するため、作成権限は不要。
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      # Lambda自身のロググループ内のストリームだけに書き込みを許可する。
      Resource = "${aws_cloudwatch_log_group.lambda.arn}:log-stream:*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_read_nginx_logs" {
  name = "aii-dev-incident-lambda-read-nginx-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:GetLogEvents"]
      # ECS側から渡されたロググループ内のストリームだけを読み取る。
      Resource = "${var.nginx_log_group_arn}:log-stream:*"
    }]
  })
}
