resource "aws_subnet" "ec2_public" {
  vpc_id                  = var.vpc_id
  cidr_block              = "172.31.0.0/20"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "rds_1" {
  vpc_id                  = var.vpc_id
  cidr_block              = "172.31.48.0/25"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = false

  tags = {
    Name = "RDS-Pvt-subnet-1"
  }
}

resource "aws_subnet" "rds_2" {
  vpc_id                  = var.vpc_id
  cidr_block              = "172.31.48.128/25"
  availability_zone       = "eu-west-3c"
  map_public_ip_on_launch = false

  tags = {
    Name = "RDS-Pvt-subnet-2"
  }
}

resource "aws_subnet" "rds_3" {
  vpc_id                  = var.vpc_id
  cidr_block              = "172.31.49.0/25"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = false

  tags = {
    Name = "RDS-Pvt-subnet-3"
  }
}

resource "aws_internet_gateway" "uptime_watch" {
  vpc_id = var.vpc_id
}

resource "aws_route_table" "main" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.uptime_watch.id
  }
}

resource "aws_route_table" "rds_private" {
  vpc_id = var.vpc_id

  tags = {
    Name = "RDS-Pvt-rt"
  }
}

resource "aws_route_table_association" "rds_1" {
  subnet_id      = aws_subnet.rds_1.id
  route_table_id = aws_route_table.rds_private.id
}

resource "aws_route_table_association" "rds_2" {
  subnet_id      = aws_subnet.rds_2.id
  route_table_id = aws_route_table.rds_private.id
}

resource "aws_route_table_association" "rds_3" {
  subnet_id      = aws_subnet.rds_3.id
  route_table_id = aws_route_table.rds_private.id
}
