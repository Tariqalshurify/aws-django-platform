# ============================================================
# RDS Subnet Group
# ============================================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

# ============================================================
# RDS PostgreSQL
# Note: multi_az=false and backup_retention_period=1 for Free Tier
# In production: set multi_az=true and backup_retention_period=7
# ============================================================
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period  = 1
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  delete_automated_backups = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot-${random_id.suffix.hex}"

  deletion_protection = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Ensure log group exists before RDS tries to auto-create it
  depends_on = [aws_cloudwatch_log_group.rds_postgresql]

  tags = { Name = "${var.project_name}-postgres" }
}
