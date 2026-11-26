resource "aws_key_pair" "uptime_watch" {
  key_name   = "key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDOs7h3Wj3Qkit/KQLaIxcE2tGVpkE4zAARjhFjnw55mb271qNxrjMi8CHPhy1VqArdqCZI3c/5/IScZ88mm+Bwto96JZPioxv4OTlewX/Gr+0NKOHE7LvGb4bZbOZl7s3i+vwgUl3s1xY+NdyMk1CXU/MZa02uGP6WKxq6z853yoazNo7vL9pSE4MtyGuqWRp9URs05bwD0F7Oabu0olLU3Q/jpCaMoJykfYxVykPzw7BGiYnqVYctb28vBxwAYarhZZklHMM6OvEFcGAacdu7CkNInzcPcwCYvwCm/0coT4b/kSV6kDR6NQhAncp3EwqZDzt546TMwzZIhKxG4Z/ key"

  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_instance" "uptime_watch" {
  ami           = "ami-01ffe9a6c3d2689bc"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.uptime_watch.key_name

  subnet_id              = "subnet-068ff0a42593458fa"
  vpc_security_group_ids = ["sg-036dc6a776b93c7ea", "sg-04e0ab92c81a0f821"]
  iam_instance_profile   = "uptime-watch-ec2-ecr-pull"

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
