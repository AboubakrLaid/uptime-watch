resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "ab9d0263244dd0326eb67015705a667e79cfe998"
  ]
}

resource "aws_iam_role" "github_actions" {
  name        = "uptime-watch-github-actions"
  description = "Allows GitHub Actions from the main branch of AboubakrLaid/uptime-watch to push Docker images to Amazon ECR."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_owner}@${var.github_repository_id}/${var.github_repository}@${var.github_branch_ids.main}:ref:refs/heads/main",
              "repo:${var.github_owner}@${var.github_repository_id}/${var.github_repository}@${var.github_branch_ids.developement}:ref:refs/heads/developement"
            ]
          }
        }
      }
    ]
  })

  max_session_duration = 3600
}

resource "aws_iam_role_policy" "github_describe_instances" {
  name = "uptime-watch-github-actions-describe-instances"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "VisualEditor0"
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_ssm" {
  name = "uptime-watch-github-actions-ssm"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendDeploymentCommandToUptimeWatchEC2"
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}::document/AWS-RunShellScript",
          "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.uptime_watch.id}"
        ]
      },
      {
        Sid      = "ReadCommandExecutionResult"
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_ses_send" {
  name = "uptime-watch-github-actions-ses-send"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSendingUptimeWatchEmails"
        Effect = "Allow"
        Action = ["ses:SendEmail"]
        Resource = [
          aws_ses_domain_identity.uptime_watch.arn,
          aws_ses_email_identity.gmail.arn
        ]
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.alert_from_address
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr_full_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
