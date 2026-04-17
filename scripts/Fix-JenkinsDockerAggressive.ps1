# Aggressive Jenkins Docker Socket Permission Fix

param(
    [string]$JenkinsIP = "3.26.175.20",
    [string]$PemKeyPath = "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem"
)

Write-Host "[*] AGGRESSIVE: Removing Jenkins container and fixing Docker socket..." -ForegroundColor Red

# Commands to completely reset and fix Jenkins
$fixCommands = @"
set -e

echo "[*] Step 1: Checking current Docker socket..."
ls -la /var/run/docker.sock

echo "[*] Step 2: Stopping Jenkins container..."
sudo docker stop jenkins 2>/dev/null || true
sleep 2

echo "[*] Step 3: Removing Jenkins container..."
sudo docker rm -f jenkins 2>/dev/null || true
sleep 2

echo "[*] Step 4: Fixing Docker socket permissions..."
sudo chmod 666 /var/run/docker.sock
echo "[OK] Docker socket permissions set to 666"

echo "[*] Step 5: Verifying socket is writable..."
ls -la /var/run/docker.sock

echo "[*] Step 6: Starting Jenkins container as root..."
sudo docker run -d \
  --name jenkins \
  --restart=unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  --user root \
  --group-add docker \
  jenkins/jenkins:lts

echo "[*] Waiting for Jenkins to start..."
sleep 8

echo "[*] Step 7: Testing Docker access from Jenkins container..."
if sudo docker exec jenkins docker ps > /dev/null 2>&1; then
    echo "[OK] Docker access VERIFIED from Jenkins!"
else
    echo "[ERROR] Docker access still failing - checking permissions..."
    sudo docker exec jenkins ls -la /var/run/docker.sock
fi

echo "[*] Step 8: Checking Jenkins container user..."
sudo docker exec jenkins whoami

echo "[*] Step 9: Checking Jenkins logs..."
sudo docker logs jenkins | tail -15

echo "[*] All done! Jenkins should be accessible at http://$JENKINS_IP:8080"

"@

Write-Host "[*] Connecting to Jenkins EC2 at $JenkinsIP..." -ForegroundColor Cyan

# Run the fix commands via SSH
try {
    ssh -i $PemKeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=30 ec2-user@$JenkinsIP $fixCommands
    Write-Host "[OK] Aggressive Docker socket fix applied!" -ForegroundColor Green
    Write-Host "[*] Jenkins should now have full Docker access" -ForegroundColor Green
    Write-Host "[*] Access Jenkins at: http://$JenkinsIP:8080" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to connect to Jenkins EC2: $_" -ForegroundColor Red
    Write-Host "[*] Verify the EC2 instance is running and SSH port 22 is open" -ForegroundColor Yellow
}
