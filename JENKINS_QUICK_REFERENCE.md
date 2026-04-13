# Jenkins Configuration Quick Reference

## 🔑 Jenkins Access Credentials

**URL:** http://localhost:8080
**Initial Password:** `74b2c2a45d0643238faaaf43c5347950`
**Status:** Running ✓

---

## ⚡ Quick Setup Commands

### Run Automated Setup (PowerShell)
```powershell
cd "d:\AI Work\ai-chatbot-devops"
.\jenkins-setup.ps1
```

### Or Manual Steps

#### 1. Verify Jenkins is Running
```powershell
docker ps -a | findstr jenkins
```

#### 2. Get Initial Password
```powershell
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

#### 3. Configure Docker Access
```powershell
docker exec -u root jenkins usermod -aG docker jenkins
```

#### 4. Verify Docker Works in Jenkins
```powershell
docker exec jenkins docker ps
docker exec jenkins docker version
```

#### 5. View Jenkins Logs
```powershell
docker logs jenkins
docker logs -f jenkins  # Follow logs in real-time
```

---

## 📋 Jenkins Setup Checklist

### Initial Setup (5-10 minutes)
- [ ] Access Jenkins at http://localhost:8080
- [ ] Paste initial password: `74b2c2a45d0643238faaaf43c5347950`
- [ ] Click "Continue"
- [ ] Click "Install suggested plugins"
- [ ] Wait for plugins to install (5-10 minutes)
- [ ] Create first admin user with secure password
- [ ] Jenkins starts and shows dashboard

### Plugin Installation (10-15 minutes)
1. Click "Manage Jenkins"
2. Click "Manage Plugins"
3. Go to "Available plugins" tab
4. Search and install:
   - [ ] Docker Pipeline
   - [ ] Docker plugin
   - [ ] Kubernetes plugin
   - [ ] Pipeline: GitHub
   - [ ] Timestamper
5. Click "Install without restart"
6. Wait for installations to complete
7. Click "Manage Jenkins" → "Restart Jenkins"
8. Wait for restart (~1 minute)

### Docker Configuration (2-5 minutes)
- [ ] Run: `docker exec -u root jenkins usermod -aG docker jenkins`
- [ ] Restart Jenkins: `docker-compose -f jenkins/docker-compose.yml restart`
- [ ] Verify: `docker exec jenkins docker ps`

### Credentials Configuration (5-10 minutes)
1. Click "Manage Jenkins" → "Manage Credentials"
2. Click "System" → "Global credentials"
3. Add Docker Hub credentials (optional):
   - [ ] Click "Add Credentials"
   - [ ] Username: Docker Hub username
   - [ ] Password: Docker Hub token
   - [ ] ID: `docker-hub-creds`
4. Add GitHub credentials (optional):
   - [ ] Click "Add Credentials"
   - [ ] Username: `git`
   - [ ] Password: GitHub personal access token
   - [ ] ID: `github-token`

### Pipeline Job Creation (5 minutes)
1. Click "New Item"
2. Enter name: `ai-chatbot-pipeline`
3. Select "Pipeline"
4. In "Pipeline" section:
   - [ ] Select "Pipeline script from SCM"
   - [ ] SCM: "Git"
   - [ ] Repository URL: `https://github.com/YOUR_USERNAME/ai-chatbot-devops.git`
   - [ ] Branch: `*/main` or `*/master`
   - [ ] Script Path: `Jenkinsfile`
5. Click "Save"

### Test Build (2-3 minutes)
1. Click "Build Now"
2. Wait for build stages:
   - [ ] Checkout
   - [ ] Build Backend
   - [ ] Build Frontend
   - [ ] Push to Registry
   - [ ] Deploy to Kubernetes
   - [ ] Health Check
3. Monitor Console Output for success

---

## 🔧 Common Configuration Tasks

### Change Jenkins Port (if 8080 is taken)
Edit `jenkins/docker-compose.yml`:
```yaml
ports:
  - "9090:8080"  # Change 9090 to your port
```

Then restart:
```powershell
docker-compose -f jenkins/docker-compose.yml down
docker-compose -f jenkins/docker-compose.yml up -d
```

### Enable Email Notifications
1. Manage Jenkins → Configure System
2. E-mail Notification
3. SMTP Server: `smtp.gmail.com`
4. Test configuration
5. Check "Use SMTP Authentication"
6. Save

### Set Timezone
1. Manage Jenkins → Configure System
2. System Time Zone: Set to your timezone
3. Save

### Configure Jenkins URL
1. Manage Jenkins → Configure System
2. Jenkins Location → Jenkins URL: `http://localhost:8080/`
3. Save

---

## 📊 Pipeline Stages Explained

The Jenkinsfile contains 6 stages:

```
┌─────────────┐
│  Checkout   │  Clone repository from GitHub
└────────┬────┘
         │
┌────────▼────────┐
│Build Backend    │  docker build backend image
└────────┬────────┘
         │
┌────────▼────────┐
│Build Frontend   │  docker build frontend image
└────────┬────────┘
         │
┌────────▼────────┐
│Push to Registry │  docker push to Docker Hub/ECR
└────────┬────────┘
         │
┌────────▼────────────┐
│Deploy to K8s        │  kubectl set image deployment
└────────┬────────────┘
         │
┌────────▼────────────┐
│Health Check         │  Verify pod status
└─────────────────────┘
```

**Typical Execution Time:** 3-5 minutes

---

## 🐛 Troubleshooting

### Jenkins Not Accessible at localhost:8080
**Problem:** Connection refused
**Solution:**
```powershell
# Verify Jenkins is running
docker ps | findstr jenkins

# Restart if needed
docker-compose -f jenkins/docker-compose.yml restart

# Check logs for errors
docker logs jenkins
```

### "Cannot connect to Docker daemon"
**Problem:** Pipeline can't build Docker images
**Solution:**
```powershell
# Grant Docker access to Jenkins
docker exec -u root jenkins usermod -aG docker jenkins

# Verify Docker socket is mounted
docker exec jenkins ls -la /var/run/docker.sock

# Restart Jenkins
docker-compose -f jenkins/docker-compose.yml restart
```

### "Git repository not found"
**Problem:** Checkout stage fails
**Solution:**
1. Verify repository URL is correct
2. If private repo, add GitHub credentials:
   - Manage Jenkins → Manage Credentials
   - Add GitHub personal access token
   - Select credentials in Pipeline job configuration

### Pipeline Stage Fails
**Problem:** Build Backend, Build Frontend, or other stages fail
**Solution:**
1. Check Console Output for detailed error
2. Look for Docker build errors
3. Verify Dockerfile paths (backend/Dockerfile, frontend/Dockerfile)
4. Test Docker build manually:
   ```powershell
   docker exec jenkins docker build -f backend/Dockerfile -t test:latest .
   ```

### Jenkins Disk Space Full
**Problem:** Builds fail with disk space errors
**Solution:**
```powershell
# Clear old build artifacts
docker exec jenkins rm -rf /var/jenkins_home/workspace/*

# Clear Docker build cache
docker exec jenkins docker system prune -a

# View disk usage
docker exec jenkins du -sh /var/jenkins_home
```

---

## 📚 Useful Jenkins Links

**Local Jenkins Instance:**
- UI: http://localhost:8080
- Pipeline Syntax: http://localhost:8080/pipeline-syntax/
- Script Console: http://localhost:8080/script

**Documentation:**
- Jenkins Official: https://www.jenkins.io/doc/
- Pipeline Tutorial: https://www.jenkins.io/doc/book/pipeline/
- Docker Integration: https://www.jenkins.io/doc/book/pipeline/docker/

---

## 🎯 Next Steps

1. **Complete Initial Setup**
   - Run setup script or follow manual steps
   - Create admin user and configure plugins

2. **Test Pipeline**
   - Create pipeline job pointing to Jenkinsfile
   - Trigger manual build ("Build Now")
   - Monitor console output for success

3. **Enable Automation**
   - Set up GitHub webhook for automatic triggers
   - Configure email notifications
   - Monitor build times and optimize

4. **Production Readiness**
   - Implement credential rotation
   - Enable HTTPS for Jenkins URL
   - Set up backup procedures
   - Configure monitoring and alerting

---

## 📞 Support

For detailed setup instructions, see: **JENKINS_SETUP_GUIDE.md**

For Jenkins issues, check: **Docker logs**: `docker logs jenkins`

For pipeline issues, check: **Console Output** in Jenkins UI

---

**Last Updated:** April 14, 2026
**Jenkins Version:** Latest LTS (in Docker)
**Status:** Ready for Configuration ✓

