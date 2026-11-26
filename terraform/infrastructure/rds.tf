resource "aws_db_subnet_group" "uptime_watch" {
  name        = "rds-ec2-db-subnet-group-1"
  description = "Created from the RDS Management Console"
  subnet_ids = [
    "subnet-02302cb8f5113bf18",
    "subnet-09931c2ba8096a429",
    "subnet-0650e48366411d492"
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
  kms_key_id            = "arn:aws:kms:eu-west-3:373080580380:key/84bc28f5-a50a-4f00-b646-5aa79afa44ef"

  username = "postgres"

  db_subnet_group_name   = aws_db_subnet_group.uptime_watch.name
  vpc_security_group_ids = ["sg-09fa01cdc133924e0"]

  publicly_accessible     = false
  multi_az                = false
  deletion_protection     = false
  backup_retention_period = 1

  backup_window      = "02:00-02:30"
  maintenance_window = "fri:02:56-fri:03:26"

  auto_minor_version_upgrade = true
  monitoring_interval        = 60
  monitoring_role_arn        = "arn:aws:iam::373080580380:role/rds-monitoring-role"

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = "arn:aws:kms:eu-west-3:373080580380:key/84bc28f5-a50a-4f00-b646-5aa79afa44ef"
  performance_insights_retention_period = 7

  iam_database_authentication_enabled = false
  copy_tags_to_snapshot               = true
  skip_final_snapshot                 = true
}
