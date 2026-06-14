output "alb_dns_name" {
  description = "Application Load Balancer DNS - open this URL in browser"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private App Subnet IDs"
  value       = aws_subnet.private[*].id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (private)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "static_bucket_name" {
  description = "S3 bucket name for static files"
  value       = aws_s3_bucket.static.bucket
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "deploy_command" {
  description = "Command to deploy the app after terraform apply"
  value       = "cd .. && bash scripts/deploy.sh ${aws_s3_bucket.static.bucket} ${var.aws_region} ${aws_autoscaling_group.app.name}"
}
