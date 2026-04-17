#!/bin/bash
set -e

JENKINS_EC2="3.26.175.20"
PEM_KEY="d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem"

echo "[*] Fixing Jenkins Docker socket permissions..."
echo "[*] Connecting to Jenkins EC2 at $JENKINS_EC2..."

# Fix Docker socket permissions on host
ssh -i "$PEM_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ec2-user@$JENKINS_EC2 << 'EOF'
set -e

echo "[*] Checking Docker socket status..."
ls -la /var/run/docker.sock

echo "[*] Checking docker group..."
getent group docker || echo "Docker group doesn't exist"

echo "[*] Fixing Docker socket permissions..."
sudo chmod 666 /var/run/docker.sock || true

echo "[*] Stopping Jenkins container..."
sudo docker stop jenkins || true
sleep 2

echo "[*] Starting Jenkins container..."
cd /home/ec2-user
sudo docker-compose up -d jenkins
sleep 5

echo "[*] Verifying Docker access from Jenkins..."
sudo docker exec jenkins docker ps > /dev/null && echo "[OK] Docker access verified!" || echo "[ERROR] Docker still not accessible"

echo "[*] Checking Jenkins logs for errors..."
sudo docker logs jenkins | tail -20

EOF

echo "[OK] Jenkins Docker fix applied!"
