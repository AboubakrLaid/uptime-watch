resource "aws_ses_domain_identity" "uptime_watch" {
  domain = var.ses_domain
}

resource "aws_ses_email_identity" "gmail" {
  email = var.ses_email
}
