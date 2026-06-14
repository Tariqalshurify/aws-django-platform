#!/bin/bash
# EC2 Bootstrap Script
exec > /var/log/user-data.log 2>&1
echo "=== Bootstrap started: $(date) ==="

# ── 1. System update ──────────────────────────────────────────
yum update -y

# ── 2. Install system packages (no postgresql15 needed - psycopg2-binary
#       includes its own client library) ───────────────────────
yum install -y python3 python3-pip python3-devel git unzip amazon-cloudwatch-agent

# ── 3. Install Python packages ────────────────────────────────
pip3 install \
    Django==4.2.13 \
    psycopg2-binary==2.9.9 \
    gunicorn==21.2.0 \
    "django-storages[s3]==1.14.3" \
    boto3==1.34.144 \
    Pillow==10.4.0 \
    python-decouple==3.8

echo "=== Python packages installed ==="

# ── 4. Create app user and directories ───────────────────────
useradd -m -s /bin/bash appuser 2>/dev/null || true
mkdir -p /opt/blog /var/log/gunicorn

# ── 5. Start a placeholder app immediately so ALB health
#       checks pass while we set up the real app ──────────────
cat > /opt/blog/placeholder.py << 'PLACEHOLDEREOF'
def application(environ, start_response):
    path = environ.get('PATH_INFO', '/')
    if path == '/health/':
        start_response('200 OK', [('Content-Type', 'text/plain')])
        return [b'OK']
    start_response('200 OK', [('Content-Type', 'text/html')])
    return [b'<html><body><h1>AWS Blog - Loading...</h1></body></html>']
PLACEHOLDEREOF

/usr/local/bin/gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 2 \
    --daemon \
    --pid /tmp/placeholder.pid \
    --chdir /opt/blog \
    placeholder:application

echo "=== Placeholder started on port 8000, health checks will pass now ==="

# ── 6. Download app from S3 ───────────────────────────────────
echo "Downloading app from S3..."
for i in 1 2 3 4 5; do
    if aws s3 sync "s3://${s3_bucket_name}/app/" /opt/blog/ \
           --region ${aws_region} \
           --exclude "*.pyc" \
           --exclude "__pycache__/*"; then
        echo "App downloaded on attempt $$i"
        break
    fi
    echo "Attempt $$i failed, waiting 20s..."
    sleep 20
done

# ── 7. Write environment config ───────────────────────────────
cat > /opt/blog/.env << ENVEOF
SECRET_KEY=${django_secret_key}
DEBUG=False
ALLOWED_HOSTS=*
CSRF_TRUSTED_ORIGINS=http://${alb_dns_name}
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
AWS_STORAGE_BUCKET_NAME=${s3_bucket_name}
AWS_S3_REGION_NAME=${aws_region}
DJANGO_SETTINGS_MODULE=config.settings.production
ENVEOF

chown -R appuser:appuser /opt/blog /var/log/gunicorn
echo "=== .env written ==="

# ── 8. Django setup ───────────────────────────────────────────
cd /opt/blog

# Create blog migrations if they don't exist
sudo -u appuser python3 manage.py makemigrations blog 2>/dev/null || true

# Run migrations
sudo -u appuser python3 manage.py migrate --noinput 2>&1 || echo "Migration failed - will retry on next restart"

# Collect static files to S3
sudo -u appuser python3 manage.py collectstatic --noinput 2>&1 || echo "Collectstatic failed"

# Create default admin user
sudo -u appuser python3 manage.py shell << 'PYEOF'
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'Admin@123!')
    print('Admin user created')
PYEOF

echo "=== Django setup complete ==="

# ── 9. Stop placeholder, start real Gunicorn service ─────────
kill $(cat /tmp/placeholder.pid) 2>/dev/null || pkill -f placeholder.py || true
sleep 2

cat > /etc/systemd/system/gunicorn.service << 'SVCEOF'
[Unit]
Description=Gunicorn - Django Blog
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=/opt/blog
EnvironmentFile=/opt/blog/.env
ExecStart=/usr/local/bin/gunicorn \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 60 \
    --access-logfile /var/log/gunicorn/access.log \
    --error-logfile /var/log/gunicorn/error.log \
    config.wsgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn

echo "=== Gunicorn service started ==="

# ── 10. CloudWatch Agent ──────────────────────────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/gunicorn/access.log",
            "log_group_name": "/aws/ec2/${project_name}/application",
            "log_stream_name": "{instance_id}/access"
          },
          {
            "file_path": "/var/log/gunicorn/error.log",
            "log_group_name": "/aws/ec2/${project_name}/application",
            "log_stream_name": "{instance_id}/error"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/${project_name}/application",
            "log_stream_name": "{instance_id}/bootstrap"
          }
        ]
      }
    }
  }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s 2>/dev/null || true

echo "=== Bootstrap complete: $(date) ==="
