# =============================================================
# Deploy Script for Windows PowerShell
# Run this AFTER terraform apply from the project root:
#   cd path\to\aws-django-platform
#   .\scripts\deploy.ps1
# =============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AWS Blog - Deploy Script (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Get values from terraform outputs
Write-Host ""
Write-Host "[1/4] Reading terraform outputs..." -ForegroundColor Yellow
Push-Location ".\terraform"
$S3_BUCKET  = terraform output -raw static_bucket_name
$ASG_NAME   = terraform output -raw asg_name
$ALB_URL    = terraform output -raw alb_dns_name
$AWS_REGION = "us-east-1"
Pop-Location

Write-Host "    S3 Bucket : $S3_BUCKET"
Write-Host "    ASG Name  : $ASG_NAME"
Write-Host "    ALB URL   : $ALB_URL"

# Upload app files to S3
Write-Host ""
Write-Host "[2/4] Uploading app to S3..." -ForegroundColor Yellow
aws s3 sync ".\app\" "s3://$S3_BUCKET/app/" `
    --region $AWS_REGION `
    --exclude "*.pyc" `
    --exclude "__pycache__/*" `
    --exclude "*.env" `
    --delete

Write-Host "    Upload complete!" -ForegroundColor Green

# Trigger EC2 Instance Refresh
Write-Host ""
Write-Host "[3/4] Triggering EC2 Instance Refresh..." -ForegroundColor Yellow
$refreshResult = aws autoscaling start-instance-refresh `
    --auto-scaling-group-name $ASG_NAME `
    --strategy Rolling `
    --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":300}' `
    --region $AWS_REGION `
    --query "InstanceRefreshId" `
    --output text

Write-Host "    Instance Refresh ID: $refreshResult"
Write-Host "    New EC2 instances will download the app from S3."
Write-Host "    This takes about 5-10 minutes..." -ForegroundColor DarkGray

# Show final info
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  App URL : $ALB_URL" -ForegroundColor White
Write-Host "  Admin   : $ALB_URL/admin" -ForegroundColor White
Write-Host "  Health  : $ALB_URL/health/" -ForegroundColor White
Write-Host ""
Write-Host "  Default admin login:" -ForegroundColor DarkGray
Write-Host "    Username: admin" -ForegroundColor DarkGray
Write-Host "    Password: Admin@123!" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Waiting for instance refresh to complete..." -ForegroundColor Yellow
Write-Host "Monitor at: https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#AutoScalingGroups:" -ForegroundColor DarkGray
