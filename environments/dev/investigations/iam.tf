data "aws_caller_identity" "current" {}

# 調査グループ：メモリアラームからの調査開始・イベント追加を受け付ける
data "aws_iam_policy_document" "investigations_alarm" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["aiops.alarms.cloudwatch.amazonaws.com"]
    }
    actions = [
      "aiops:CreateInvestigation",
      "aiops:CreateInvestigationEvent",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudwatch:ap-northeast-1:${data.aws_caller_identity.current.account_id}:alarm:aii-dev-investigations-ecs-memory-high"]
    }
  }
}

# AI調査用ロール：AI調査機能による利用を許可する
resource "aws_iam_role" "investigations" {
  name = "aii-dev-cloudwatch-investigations"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "aiops.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:aiops:ap-northeast-1:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

# AI調査用ロール：メトリクスとアラーム・ダッシュボードを読む
resource "aws_iam_role_policy" "investigations_metrics" {
  name = "aii-dev-investigations-read-metrics"
  role = aws_iam_role.investigations.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:ListDashboards",
        "cloudwatch:GetDashboard",
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

# AI調査用ロール：Nginxのログを検索する
resource "aws_iam_role_policy" "investigations_logs" {
  name = "aii-dev-investigations-read-nginx-logs"
  role = aws_iam_role.investigations.id

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
        # Logs APIの認可で使う両方のARN表記を、同じロググループに限定して許可する。
        Resource = [
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aii/dev/ecs/nginx",
          "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:log-group:/aii/dev/ecs/nginx:*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeQueryDefinitions",
          "logs:ListLogGroupsForEntity",
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

# AI調査用ロール：サービスとテレメトリの関連を探す。東京の読み取りだけを許可する。
resource "aws_iam_role_policy" "investigations_discovery" {
  name = "aii-dev-investigations-discover-resources"
  role = aws_iam_role.investigations.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "application-signals:ListServices",
        "application-signals:ListObservedEntities",
        "application-signals:ListServiceLevelObjectives",
        "cloudformation:GetResource",
        "cloudtrail:DescribeTrails",
        "tag:GetResources",
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

# AI調査用ロール：ECSの構成・状態を読む
resource "aws_iam_role_policy" "investigations_ecs" {
  name = "aii-dev-investigations-read-ecs"
  role = aws_iam_role.investigations.id

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
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:cluster/aii-dev-ecs-cluster",
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:service/aii-dev-ecs-cluster/aii-dev-ecs-service-nginx",
          "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:task/aii-dev-ecs-cluster/*",
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
            "ecs:cluster" = "arn:aws:ecs:ap-northeast-1:${data.aws_caller_identity.current.account_id}:cluster/aii-dev-ecs-cluster"
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

# SNS：AI調査からの通知を受け付ける
resource "aws_sns_topic_policy" "investigations" {
  arn = aws_sns_topic.investigations.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "aiops.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.investigations.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}
