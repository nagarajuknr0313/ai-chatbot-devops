# Fix Jenkins Docker socket permissions

param(
    [string]$JenkinsIP = "3.26.175.20",
    [string]$PemKeyPath = "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem"
)

Write-Host "[*] Fixing Jenkins Docker socket permissions..." -ForegroundColor Cyan

# Commands to run on EC2
$fixCommands = @"
set -e

echo "[*] Checking Docker socket permissions..."
ls -la /var/run/docker.sock || true

echo "[*] Fixing Docker socket permissions to 666..."
sudo chmod 666 /var/run/docker.sock

echo "[*] Stopping Jenkins container..."
sudo docker stop jenkins || true
sleep 3

echo "[*] Removing old Jenkins container to ensure clean start..."
sudo docker rm jenkins || true
sleep 2

echo "[*] Restarting Jenkins with docker-compose..."
cd /home/ec2-user/jenkins-setup || cd /home/ec2-user
sudo docker-compose up -d jenkins 2>/dev/null || sudo docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  --user root \
  jenkins/jenkins:lts

sleep 5

echo "[*] Verifying Docker daemon access..."
sudo docker exec jenkins docker ps > /dev/null 2>&1 && echo "[OK] Docker access works!" || echo "[WARNING] Docker access may still have issues"

echo "[*] Checking jenkins user in container..."
sudo docker exec jenkins id

echo "[*] Jenkins logs (last 10 lines):"
sudo docker logs jenkins | tail -10

"@

Write-Host "[*] Connecting to Jenkins EC2 at $JenkinsIP..." -ForegroundColor Cyan

# Run the fix commands via SSH
ssh -i $PemKeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=30 ec2-user@$JenkinsIP $fixCommands

Write-Host "[OK] Jenkins Docker fix applied! The pipeline should work on the next run." -ForegroundColor Green
