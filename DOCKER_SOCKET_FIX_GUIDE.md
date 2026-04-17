# Jenkins Docker Socket Permission - Manual Fix Guide

## Quick Fix (Try This First)

### Option 1: Run PowerShell Script
```powershell
cd "d:\AI Work\ai-chatbot-devops"
.\scripts\Fix-JenkinsDockerAggressive.ps1
```

This will:
- Stop and remove Jenkins container
- Fix Docker socket permissions (chmod 666)
- Restart Jenkins as root with Docker socket mounted
- Verify access works

---

## If PowerShell Script Times Out (SSH Connection)

### Option 2: Direct EC2 SSH Terminal

Open a PowerShell terminal and run:

```powershell
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem" ec2-user@3.26.175.20
```

Then run these commands on the EC2 instance:

```bash
# Stop Jenkins
sudo docker stop jenkins 2>/dev/null || true
sleep 2

# Remove Jenkins container
sudo docker rm -f jenkins 2>/dev/null || true
sleep 2

# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Start Jenkins as root with Docker socket access
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

# Wait and verify
sleep 8
sudo docker exec jenkins docker ps

# Check Jenkins is running
curl http://localhost:8080
```

---

## Option 3: AWS EC2 Systems Manager Session (No SSH)

1. Go to AWS Console → Systems Manager → Session Manager
2. Start session to Jenkins instance: `i-0c4a5d471a82cba69`
3. Run the commands from Option 2 above

---

## Key Points

- **Docker socket** must have read/write permissions (666)
- **Jenkins container** must run as **root** (`--user root`)
- **Docker socket** must be mounted: `-v /var/run/docker.sock:/var/run/docker.sock`
- **Docker CLI** inside container needs access to the mounted socket

---

## Verification

After fixing, verify Docker works in Jenkins:

```bash
sudo docker exec jenkins docker ps
sudo docker exec jenkins docker --version
```

Both should return without "permission denied" errors.

---

## If Issues Persist

1. Check Docker socket exists: `ls -la /var/run/docker.sock`
2. Check Jenkins container is running: `sudo docker ps | grep jenkins`
3. Check Jenkins logs: `sudo docker logs jenkins`
4. Check Jenkins user: `sudo docker exec jenkins whoami` (should show "root")
5. Check socket permissions: `sudo docker exec jenkins ls -la /var/run/docker.sock`

