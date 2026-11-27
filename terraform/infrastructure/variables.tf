variable "aws_region" {
  description = "AWS region where the infrastructure is deployed."
  type        = string
  default     = "eu-west-3"
}

variable "vpc_id" {
  description = "Existing VPC ID used by the infrastructure."
  type        = string
  default     = "vpc-0fac56610967ebc7b"
}

variable "ec2_subnet_id" {
  description = "Existing public subnet ID used by the EC2 instances."
  type        = string
  default     = "subnet-068ff0a42593458fa"
}

variable "ami_id" {
  description = "AMI ID used by both EC2 instances."
  type        = string
  default     = "ami-01ffe9a6c3d2689bc"
}

variable "rds_kms_key_id" {
  description = "KMS key ID or ARN used to encrypt the RDS instance."
  type        = string
  default     = "arn:aws:kms:eu-west-3:373080580380:key/84bc28f5-a50a-4f00-b646-5aa79afa44ef"
}

variable "github_owner" {
  description = "GitHub repository owner allowed to assume the deployment role."
  type        = string
  default     = "AboubakrLaid"
}

variable "github_repository" {
  description = "GitHub repository name allowed to assume the deployment role."
  type        = string
  default     = "uptime-watch"
}

variable "github_repository_id" {
  description = "Numeric GitHub repository ID."
  type        = string
  default     = "107946074"
}

variable "github_branch_ids" {
  description = "GitHub subject-ID values allowed to assume the deployment role."
  type        = map(string)
  default = {
    main         = "1433115526"
    developement = "1433115526"
  }
}

variable "ses_domain" {
  description = "Domain identity used for application email."
  type        = string
  default     = "upwatch.live"
}

variable "ses_email" {
  description = "Email identity used for application email."
  type        = string
  default     = "belmiloudaboubakr.contact@gmail.com"
}

variable "alert_from_address" {
  description = "Verified SES sender address."
  type        = string
  default     = "alerts@upwatch.live"
}

variable "ssh_key_name" {
  description = "Name for the EC2 key pair."
  type        = string
  default     = "key"
}

variable "ssh_public_key" {
  description = "Public SSH key uploaded to AWS."
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDOs7h3Wj3Qkit/KQLaIxcE2tGVpkE4zAARjhFjnw55mb271qNxrjMi8CHPhy1VqArdqCZI3c/5/IScZ88mm+Bwto96JZPioxv4OTlewX/Gr+0NKOHE7LvGb4bZbOZl7s3i+vwgUl3s1xY+NdyMk1CXU/MZa02uGP6WKxq6z853yoazNo7vL9pSE4MtyGuqWRp9URs05bwD0F7Oabu0olLU3Q/jpCaMoJykfYxVykPzw7BGiYnqVYctb28vBxwAYarhZZklHMM6OvEFcGAacdu7CkNInzcPcwCYvwCm/0coT4b/kSV6kDR6NQhAncp3EwqZDzt546TMwzZIhKxG4Z/ key"
}

variable "rds_security_group_id" {
  description = "Existing RDS security group ID used by EC2 egress rules."
  type        = string
  default     = "sg-09fa01cdc133924e0"
}

variable "ec2_security_group_id" {
  description = "Existing EC2 security group ID used by RDS ingress rules."
  type        = string
  default     = "sg-04e0ab92c81a0f821"
}
