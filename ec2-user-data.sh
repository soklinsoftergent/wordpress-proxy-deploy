#!/bin/bash
set -euo pipefail

# === configuration (edit only if needed) ===
REPO_URL="https://github.com/soklinsoftergent/wordpress-proxy-deploy.git"
APP_DIR="/home/ec2-user/wordpress-proxy-deploy"
S3_BUCKET="firstbucket884"
S3_KEY="credentials.env"
# ===========================================

# fetch region from metadata (safer than hardcoding)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region 2>/dev/null || echo "us-east-1")

# Update & install prerequisites
if command -v yum >/dev/null 2>&1; then
  yum update -y
  amazon-linux-extras enable epel -y || true
  yum install -y git jq curl unzip awscli || true
else
  apt-get update -y
  apt-get install -y git jq curl unzip awscli || true
fi

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
  if command -v yum >/dev/null 2>&1; then
    amazon-linux-extras install -y docker
  else
    apt-get install -y docker.io
  fi
  systemctl enable --now docker
fi

# Install docker-compose (fallback locations)
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  # try v2 plugin path first
  mkdir -p /usr/libexec/docker/cli-plugins || true
  curl -SL "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
  chmod +x /usr/libexec/docker/cli-plugins/docker-compose || true

  # fallback to /usr/local/bin
  if [ ! -x /usr/libexec/docker/cli-plugins/docker-compose ]; then
    curl -SL "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi
fi

# Ensure docker daemon running
systemctl start docker || true
systemctl enable docker || true

# Ensure a user exists
USER_HOME="/home/ec2-user"
if [ ! -d "$USER_HOME" ]; then
  USER_HOME="/root"
fi

# Clone repo fresh (delete old copy if exists to avoid conflicts)
rm -rf "${APP_DIR}"
git clone "${REPO_URL}" "${APP_DIR}"
cd "${APP_DIR}"

# Download credentials from S3 (requires instance IAM role with s3:GetObject)
echo "Attempting to download env from s3://${S3_BUCKET}/${S3_KEY} in region ${REGION}"
aws s3 cp "s3://${S3_BUCKET}/${S3_KEY}" .env --region "${REGION}" || {
  echo "ERROR: Failed to download .env from S3. Check IAM role or S3 path."
  exit 1
}

chown ec2-user:ec2-user .env || true
chmod 600 .env || true

# Start the stack
# If you want to always use docker compose V2 plugin, run 'docker compose'
if command -v docker >/dev/null 2>&1; then
  docker compose down || true
  docker compose pull || true
  docker compose up -d
else
  echo "docker not found"
  exit 1
fi

echo "Bootstrap finished."
exit 0

