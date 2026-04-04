#!/bin/bash
set -e

echo "=== Diagram Generator - EC2 Bootstrap ==="

# ── System packages ──────────────────────────────────────────────────────────
yum update -y
yum install -y docker jq aws-cli

# ── Start Docker ─────────────────────────────────────────────────────────────
systemctl enable docker
systemctl start docker

# ── Install Docker Compose v2 plugin ─────────────────────────────────────────
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# ── App directory ─────────────────────────────────────────────────────────────
APP_DIR=/opt/diagram-generator
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# ── Write .env ────────────────────────────────────────────────────────────────
cat > "$APP_DIR/.env" << 'ENVEOF'
DATABASE_URL=postgresql://${db_username}:${db_password}@${rds_endpoint_placeholder}:5432/diagramdb
NODE_ENV=production
PORT=3000
AWS_REGION=${aws_region}
S3_BUCKET=${s3_bucket}
CORS_ALLOWED_ORIGIN=${allowed_origin}
ENVEOF
# Note: RDS endpoint is written by the deploy script after terraform output is known.
# The deploy workflow will overwrite DATABASE_URL via SSH before bringing containers up.

# ── Write docker-compose.prod.yml ─────────────────────────────────────────────
cat > "$APP_DIR/docker-compose.prod.yml" << 'COMPOSEEOF'
services:
  api:
    image: ${ecr_registry}/${ecr_repo}:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file: /opt/diagram-generator/.env
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
COMPOSEEOF

# ── ECR login helper (runs at boot and is called by deploy) ───────────────────
cat > /usr/local/bin/ecr-login << 'LOGINEOF'
#!/bin/bash
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${ecr_registry}
LOGINEOF
chmod +x /usr/local/bin/ecr-login

# ── Systemd service so the container restarts on reboot ──────────────────────
cat > /etc/systemd/system/diagram-generator.service << 'SERVICEEOF'
[Unit]
Description=Diagram Generator API
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/diagram-generator
ExecStart=/bin/bash -c '/usr/local/bin/ecr-login && docker compose -f docker-compose.prod.yml pull && docker compose -f docker-compose.prod.yml up -d'
ExecStop=/usr/bin/docker compose -f /opt/diagram-generator/docker-compose.prod.yml down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable diagram-generator.service

echo "=== Bootstrap complete. Container will start on first deploy. ==="
