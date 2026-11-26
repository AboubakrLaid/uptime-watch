resource "aws_ses_domain_identity" "uptime_watch" {
  domain = "upwatch.live"
}

resource "aws_ses_email_identity" "gmail" {
  email = "belmiloudaboubakr.contact@gmail.com"
}
