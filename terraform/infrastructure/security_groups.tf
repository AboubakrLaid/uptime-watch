resource "aws_security_group" "web" {
  name        = "launch-wizard-1"
  description = "launch-wizard-1 created 2026-10-28T11:56:54.898Z"
  vpc_id      = "vpc-0fac56610967ebc7b"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_rds" {
  name                   = "ec2-rds-1"
  description            = "Security group attached to instances to securely connect to uptime-watch-db-prod. Modification could lead to connection loss."
  vpc_id                 = "vpc-0fac56610967ebc7b"
  revoke_rules_on_delete = false

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-09fa01cdc133924e0"]
    description     = "Rule to allow connections to uptime-watch-db-prod from any instances this security group is attached to"
  }
}

resource "aws_security_group" "rds_ec2" {
  name                   = "rds-ec2-1"
  description            = "Security group attached to uptime-watch-db-prod to allow EC2 instances with specific security groups attached to connect to the database. Modification could lead to connection loss."
  vpc_id                 = "vpc-0fac56610967ebc7b"
  revoke_rules_on_delete = false

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-04e0ab92c81a0f821"]
    description     = "Rule to allow connections from EC2 instances with sg-04e0ab92c81a0f821 attached"
  }
}
