# ============================================================
# AWS Backup Vault
# ============================================================
resource "aws_backup_vault" "main" {
  name = "${var.project_name}-backup-vault"
  tags = { Name = "${var.project_name}-backup-vault" }
}

# ============================================================
# AWS Backup Plan (Daily + Weekly)
# ============================================================
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  # Daily backup at 2 AM UTC — retained 30 days
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 30
    }
  }

  # Weekly backup on Sunday at 3 AM UTC — retained 90 days
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)"
    start_window      = 60
    completion_window = 300

    lifecycle {
      delete_after = 90
    }
  }

  tags = { Name = "${var.project_name}-backup-plan" }
}

# ============================================================
# Backup Selection: RDS PostgreSQL
# ============================================================
resource "aws_backup_selection" "rds" {
  name         = "${var.project_name}-rds-backup"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.main.arn
  ]
}
