resource "aws_db_subnet_group" "uptime_watch" {
  name        = "rds-ec2-db-subnet-group-1"
  description = "Created from the RDS Management Console"
  subnet_ids = [
    aws_subnet.rds_1.id,
    aws_subnet.rds_2.id,
    aws_subnet.rds_3.id
  ]
}

resource "aws_db_instance" "uptime_watch" {
  identifier = "uptime-watch-db-prod"

  engine         = "postgres"
  engine_version = "18.3"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = var.rds_kms_key_id

  username = "postgres"

  db_subnet_group_name   = aws_db_subnet_group.uptime_watch.name
  vpc_security_group_ids = [aws_security_group.rds_ec2.id]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  backup_retention_period = 1

  backup_window      = "02:00-02:30"
  maintenance_window = "fri:02:56-fri:03:26"

  auto_minor_version_upgrade = true
  monitoring_interval        = 60
  monitoring_role_arn        = data.aws_iam_role.rds_monitoring.arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.rds_kms_key_id
  performance_insights_retention_period = 7

  iam_database_authentication_enabled = false
  copy_tags_to_snapshot               = true
  skip_final_snapshot                 = true
}

data "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"
}
