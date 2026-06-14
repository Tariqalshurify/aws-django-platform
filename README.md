# AWS Django Platform

A production-grade, highly-available Django web application deployed on AWS using **Terraform** as the sole Infrastructure as Code tool. The full stack — 73 AWS resources — is provisioned with a single `terraform apply`.

![AWS](https://img.shields.io/badge/AWS-%23232F3E.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Django](https://img.shields.io/badge/Django-%23092E20.svg?style=for-the-badge&logo=django&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)

---

## Architecture

![Architecture Diagram](architecture.png)

The diagram source is in [`architecture.drawio`](architecture.drawio) — open with [diagrams.net](https://app.diagrams.net) to edit.

---

## Features

| Pillar | Implementation |
|--------|---------------|
| **High Availability** | Multi-AZ deployment across two Availability Zones, ALB health checks, ASG minimum 2 instances |
| **Scalability** | Auto Scaling Group (2–6 instances), CPU-based scale-out at 75% / scale-in at 25% |
| **Security** | AWS WAF v2 (4 rules), private subnets, 3 Security Groups, IAM least-privilege, no hardcoded secrets |
| **Reliability** | AWS Backup daily (30d) + weekly (90d), CloudWatch alarms, SNS email alerting |
| **Observability** | CloudWatch Dashboard (7 widgets), 6 alarms, CloudWatch Logs, multi-region CloudTrail |
| **Cost** | All free-tier eligible where possible; ~$0 idle, ~$80/mo at light production load |

---

## AWS Services Used

VPC · Subnets · Internet Gateway · NAT Gateways · Elastic IPs · Route Tables · Network ACLs · Security Groups · Application Load Balancer · Target Groups · EC2 · Launch Template · Auto Scaling Group · RDS PostgreSQL · DB Subnet Group · S3 (3 buckets) · WAF v2 · CloudWatch (Dashboard, Alarms, Logs) · CloudTrail · SNS · AWS Backup · IAM (Roles, Policies, Instance Profile)

---

## Project Structure

```
.
├── app/                      # Django application (front-end + back-end)
│   ├── blog/                 # Blog app (models, views, templates)
│   ├── config/               # Django settings (base / production)
│   └── manage.py
├── terraform/                # 14 Terraform files (73 resources)
│   ├── vpc.tf
│   ├── alb.tf
│   ├── ec2.tf
│   ├── rds.tf
│   ├── s3.tf
│   ├── waf.tf
│   ├── cloudwatch.tf
│   ├── cloudtrail.tf
│   ├── iam.tf
│   ├── backup.tf
│   ├── security_groups.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── scripts/
│   └── user_data.sh.tpl      # EC2 bootstrap (installs Python, downloads app, runs migrations)
└── architecture.drawio
```

---

## Deployment

### Prerequisites
- AWS account with `AdministratorAccess` IAM user
- AWS CLI installed and configured (`aws configure`)
- Terraform ≥ 1.0
- Python 3.9+

### Steps

```bash
# 1. Configure your variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set db_password, django_secret_key, alert_email

# Generate strong secrets:
#   openssl rand -base64 32

# 2. Deploy infrastructure (~10 min)
terraform init
terraform apply -auto-approve

# 3. Upload application code to S3
BUCKET=$(terraform output -raw static_bucket_name)
aws s3 sync ../app/ s3://$BUCKET/app/ --exclude "*.pyc" --exclude "__pycache__/*"

# 4. Trigger instance refresh so EC2 pulls the new code (~5 min)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name aws-django-platform-asg

# 5. Open the application
echo "http://$(terraform output -raw alb_dns_name)"
```

### Destruction

```bash
# Empty S3 buckets first (CloudTrail writes after destroy starts)
aws s3 rm s3://$(terraform output -raw static_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw alb_logs_bucket_name) --recursive
aws s3 rm s3://$(terraform output -raw cloudtrail_bucket_name) --recursive

# Delete leftover RDS log groups (RDS doesn't clean these on destroy)
aws logs delete-log-group --log-group-name "/aws/rds/instance/aws-django-platform-postgres/postgresql"

terraform destroy -auto-approve
```

---

## Security Notes

- **`terraform.tfvars` is gitignored.** Never commit real passwords or secret keys.
- All secrets are injected at boot via Terraform `templatefile`, never written to source.
- EC2 instances use an **IAM Instance Profile** — no AWS credentials are stored on disk.
- RDS sits in a **private subnet with no internet route**.
- WAF v2 blocks SQLi, XSS, known bad inputs, and rate-limits IPs to 2000 req / 5 min.
- For production, also: enable HTTPS (ACM + ALB :443 listener), enable RDS Multi-AZ, move secrets to **AWS Secrets Manager**.

---

## Cost (us-east-1, idle)

| Service | Cost |
|---------|------|
| EC2 (2× t3.micro) | Free tier |
| RDS db.t3.micro | Free tier |
| NAT Gateways (×2) | ~$64/mo |
| ALB | ~$16/mo |
| WAF | ~$7/mo |
| CloudWatch | ~$5/mo |
| S3 / CloudTrail | <$1/mo |
| **Total** | **~$93/mo idle** |

NAT Gateway is the dominant cost. For a dev environment, reduce to a single NAT Gateway to cut this in half.

---

## License

MIT
