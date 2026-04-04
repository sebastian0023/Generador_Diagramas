#!/bin/bash
set -e

echo "Starting Diagram Generator backend setup..."

# Update system
sudo yum update -y

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Install git
sudo yum install -y git

# Install PM2
sudo npm install -g pm2

# Create app directory
mkdir -p /opt/diagram-generator
cd /opt/diagram-generator

# Clone repository (CAMBIAR URL)
# git clone https://github.com/YOUR_USERNAME/diagram-generator.git .
# Por ahora, solo crear estructura
mkdir -p backend frontend

# Backend setup
cd backend
npm init -y
npm install express cors dotenv @prisma/client aws-sdk
npm install -D prisma nodemon

# Create .env file (CAMBIAR valores)
cat > .env << 'EOF'
DATABASE_URL="postgresql://diagramadmin:<DB_PASSWORD>@RDS_ENDPOINT:5432/diagramdb"
NODE_ENV="production"
PORT=3000
AWS_REGION="us-east-1"
S3_BUCKET="diagram-generator-ACCOUNT_ID-us-east-1"
EOF

echo "Backend dependencies installed!"
echo "Waiting for RDS to be ready..."

# Try to connect to RDS (wait up to 5 minutes)
for i in {1..60}; do
  if pg_isready -h RDS_ENDPOINT -U diagramadmin &>/dev/null; then
    echo "RDS is ready!"
    break
  fi
  echo "Waiting for RDS... ($i/60)"
  sleep 5
done

echo "Setup complete! Backend ready to start."
