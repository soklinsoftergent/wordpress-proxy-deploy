#!/bin/bash
set -e

# Update & install dependencies
yum update -y
amazon-linux-extras enable docker
yum install -y docker git awscli
systemctl start docker
systemctl enable docker

# Install docker-compose (latest v2)
curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone your repo
cd /home/ec2-user
git clone https://github.com/soklinsoftergent/wordpress-proxy-deploy.git
cd wordpress-proxy-deploy

# Pull secrets from S3
aws s3 cp s3://wordpress-proxy-secrets/.env .env

# Start services
docker-compose up -d

