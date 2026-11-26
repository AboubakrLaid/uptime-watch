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
          Federated = "arn:aws:iam::373080580380:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:AboubakrLaid@107946074/uptime-watch@1433115526:ref:refs/heads/main",
              "repo:AboubakrLaid@107946074/uptime-watch@1433115526:ref:refs/heads/developement"
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
          "arn:aws:ssm:eu-west-3::document/AWS-RunShellScript",
          "arn:aws:ec2:eu-west-3:373080580380:instance/i-00d6c3e1a6a3b4929"
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
          "arn:aws:ses:eu-west-3:373080580380:identity/upwatch.live",
          "arn:aws:ses:eu-west-3:373080580380:identity/belmiloudaboubakr.contact@gmail.com"
        ]
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "alerts@upwatch.live"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr_full_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
