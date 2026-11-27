resource "aws_key_pair" "uptime_watch" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_instance" "uptime_watch" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.uptime_watch.key_name

  subnet_id              = var.ec2_subnet_id
  vpc_security_group_ids = [aws_security_group.web.id, aws_security_group.ec2_rds.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_pull.name

  monitoring = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 12
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name = "upwatch web server"
  }
}

resource "aws_eip" "uptime_watch" {
  instance = aws_instance.uptime_watch.id
  domain   = "vpc"
}

resource "aws_instance" "uptime_watch_practice" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.uptime_watch.key_name
  ebs_optimized = true

  subnet_id              = var.ec2_subnet_id
  vpc_security_group_ids = [aws_security_group.web.id, aws_security_group.ec2_rds.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ecr_pull.name

  monitoring = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 12
    delete_on_termination = true
    encrypted             = false
  }

  tags = {
    Name      = "uptime_watch_secondary"
    ManagedBy = "Terraform"
    Purpose   = "Infrastructure parity target"
  }
}

resource "aws_eip" "uptime_watch_practice" {
  instance = aws_instance.uptime_watch_practice.id
  domain   = "vpc"
}
