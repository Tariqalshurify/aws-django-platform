#!/bin/bash
# =============================================================
# Deploy Script
# Usage: bash scripts/deploy.sh <s3-bucket-name> <aws-region> <asg-name>
#
# Run this AFTER terraform apply.
# It packages the Django app, uploads to S3, and triggers
# an EC2 instance refresh so new instances get the latest code.
# =============================================================
set -e

S3_BUCKET=${1:-$(terraform -chdir=terraform output -raw static_bucket_name)}
AWS_REGION=${2:-"us-east-1"}
ASG_NAME=${3:-$(terraform -chdir=terraform output -raw asg_name)}

if [ -z "$S3_BUCKET" ]; then
    echo "ERROR: S3 bucket name is required."
    echo "Usage: bash scripts/deploy.sh <s3-bucket-name> <aws-region> <asg-name>"
    exit 1
fi

echo "============================================"
echo "  AWS Blog - Deployment Script"
echo "============================================"
echo "  S3 Bucket : $S3_BUCKET"
echo "  Region    : $AWS_REGION"
echo "  ASG Name  : $ASG_NAME"
echo "============================================"

# Step 1: Create deployment package
echo ""
echo "[1/4] Packaging application..."
cd "$(dirname "$0")/.."

# Create temp directory for clean package
TEMP_DIR=$(mktemp -d)
cp -r app/. "$TEMP_DIR/"
# Remove local .env if exists (server uses its own)
rm -f "$TEMP_DIR/.env"
rm -rf "$TEMP_DIR/__pycache__"
find "$TEMP_DIR" -name "*.pyc" -delete
find "$TEMP_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

echo "    Package ready at: $TEMP_DIR"

# Step 2: Upload application to S3
echo ""
echo "[2/4] Uploading application to S3..."
aws s3 sync "$TEMP_DIR/" "s3://$S3_BUCKET/app/" \
    --region "$AWS_REGION" \
    --exclude "*.pyc" \
    --exclude "__pycache__/*" \
    --delete

rm -rf "$TEMP_DIR"
echo "    Upload complete!"

# Step 3: Trigger ASG Instance Refresh
if [ -n "$ASG_NAME" ]; then
    echo ""
    echo "[3/4] Triggering EC2 Instance Refresh..."
    REFRESH_ID=$(aws autoscaling start-instance-refresh \
        --auto-scaling-group-name "$ASG_NAME" \
        --strategy Rolling \
        --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":300}' \
        --region "$AWS_REGION" \
        --query 'InstanceRefreshId' \
        --output text)

    echo "    Instance Refresh started: $REFRESH_ID"
    echo "    New instances will download the latest code from S3."
    echo "    This takes ~5-10 minutes. Monitor at:"
    echo "    https://$AWS_REGION.console.aws.amazon.com/ec2/v2/home?region=$AWS_REGION#AutoScalingGroups"
else
    echo ""
    echo "[3/4] Skipping instance refresh (no ASG name provided)"
fi

# Step 4: Show ALB URL
echo ""
echo "[4/4] Getting application URL..."
ALB_URL=$(terraform -chdir=terraform output -raw alb_dns_name 2>/dev/null || echo "Check terraform outputs")
echo ""
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
echo "  App URL: $ALB_URL"
echo "  Admin  : $ALB_URL/admin"
echo "  Health : $ALB_URL/health/"
echo ""
echo "  Default admin credentials:"
echo "    Username: admin"
echo "    Password: Admin@123!"
echo "  (Change this immediately!)"
echo "============================================"
