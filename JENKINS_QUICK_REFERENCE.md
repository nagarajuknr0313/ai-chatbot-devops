# Jenkins Quick Reference Card

## 🎯 Quick Decision: Local vs EC2?

| Need | Local | EC2 |
|------|-------|-----|
| Auto-deploy on push? | ❌ | ✅ |
| Team access? | ❌ | ✅ |
| 24/7 availability? | ❌ | ✅ |
| Cost? | $0 | $29/mo |
| Learning? | ✅ | ✅ |

**Recommendation: EC2 for production, Local for testing** ⭐

---

## 🚀 5-Minute EC2 Jenkins Setup

```bash
# 1. SSH into EC2
ssh -i your-key.pem ec2-user@ec2-ip-address

# 2. Run setup
curl -o setup.sh https://raw.githubusercontent.com/your-repo/scripts/setup-jenkins-ec2.sh
bash setup.sh

# 3. Get password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# 4. Open browser
http://ec2-ip:8080

# 5. Complete setup in UI
# - Paste password
# - Install plugins
# - Create admin user
# - Add AWS credentials
# - Create pipeline job
```

**Total time: ~20 minutes!**

---

## 📋 Jenkins Workflow

```
push code → GitHub webhook → Jenkins build → ECR push → EKS deploy → Live!
```

**Timeline**: 5-8 minutes from push to production

---

## 🔧 Common Jenkins Tasks

### **Add AWS Credentials**
```
Jenkins → Manage Jenkins → Manage Credentials
→ Add AWS Credentials
→ Enter Access Key & Secret Key
```

### **Setup GitHub Webhook**
```
Your GitHub Repo → Settings → Webhooks
→ Add webhook
→ Payload URL: http://ec2-ip:8080/github-webhook/
→ Events: Push events
→ Save
```

### **Create Pipeline Job**
```
Jenkins → New Item
→ Job name: chatbot-deployment
→ Pipeline
→ Definition: Pipeline script from SCM
→ SCM: Git
→ Repository: your-github-repo
→ Script Path: Jenkinsfile
→ Save
```

### **Manually Trigger Build**
```
Jenkins → Job → Build Now
```

### **View Build Logs**
```
Jenkins → Job → Build #N → Console Output
```

---

## 🐛 Quick Troubleshooting

### **ECR Login Fails**
```bash
# Check credentials
aws sts get-caller-identity
# Should show your account ID
```

### **kubectl Not Found**
```bash
# Install on Jenkins instance
curl -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl
```

### **Webhook Not Triggering**
```
1. Check Jenkins UI → Manage Jenkins → Configure System → GitHub
2. Verify webhook in GitHub repo settings
3. Check Jenkins logs for errors
```

### **Pods Not Ready After Deploy**
```bash
# SSH to EC2
kubectl get pods -n chatbot -o wide
kubectl logs -n chatbot pod-name
kubectl describe pod -n chatbot pod-name
```

---

## 📊 Your Current Status

| Component | Status |
|-----------|--------|
| Backend | ✅ 3/3 pods running |
| Frontend | ✅ 2/2 pods running |
| OpenAI | ✅ Configured |
| ECR | ✅ Images pushed |
| EKS | ✅ Deployments live |
| Jenkins | ⏳ Configure EC2 |

---

## 📁 Key Files Reference

| File | Purpose |
|------|---------|
| `Jenkinsfile` | Pipeline definition |
| `JENKINS_AUTOMATION_GUIDE.md` | Complete setup |
| `JENKINS_LOCAL_VS_EC2.md` | Decision guide |
| `JENKINS_ARCHITECTURE.md` | Architecture docs |
| `scripts/setup-jenkins-ec2.sh` | Auto-setup |
| `scripts/jenkins-iam-policy.json` | AWS permissions |

---

## 🔗 Useful Links

```
Jenkins UI:           http://ec2-ip:8080
Backend API:          http://backend-lb:8000
Frontend:             http://frontend-lb
ECR Repository:       AWS Console → ECR
EKS Cluster:          AWS Console → EKS
```

---

## 💡 Pro Tips

1. **Test Locally First**: Use local Docker Compose before pushing
2. **Commit Often**: Small commits = easier debugging
3. **Monitor Logs**: Check Jenkins console for errors
4. **Set Slack Alerts**: Get notified of builds
5. **Tag Releases**: Use Git tags for versioning
6. **Backup Jenkins**: Weekly backup of /var/lib/jenkins

---

## 🎯 Daily Workflow

### **With EC2 Jenkins** ✅
```
Morning:
  1. Write code locally
  2. Test with Docker Compose
  3. Commit & push to GitHub
  4. Walk away ☕

Jenkins (automatically):
  1. Builds image
  2. Pushes to ECR
  3. Updates EKS
  4. Sends Slack message

Your job:
  1. Monitor in Slack
  2. Check production
  3. Report issues
  4. Celebrate automation! 🎉
```

### **Without Jenkins** ❌
```
1. Write code
2. Test locally
3. Commit & push
4. Run build-and-push-ecr.ps1
5. Run kubectl commands
6. Wait for pods
7. Check deployment
8. Manual, error-prone, slow
```

**Difference: 5 minutes vs 30 seconds automation**

---

## 📞 Quick Help

**Problem**: Pipeline fails  
**Solution**: Check `Jenkins → Build #N → Console Output`

**Problem**: Pods not ready  
**Solution**: `kubectl logs -n chatbot pod-name`

**Problem**: Images not in ECR  
**Solution**: Check `docker push` errors in Jenkins console

**Problem**: Webhook not firing  
**Solution**: Verify in GitHub settings and Jenkins logs

---

## 🚀 Next Action

**Pick one:**

| Option | Time | Effort |
|--------|------|--------|
| **Keep local only** | 0 min | 0 |
| **Add EC2 Jenkins** | 20 min | Easy |
| **Full automation** | 25 min | Easy |

**Recommendation: 20-minute investment = months of time savings! ⭐**

---

## ✅ Checklist Before Going Production

- [ ] Jenkins running on EC2
- [ ] AWS credentials configured
- [ ] GitHub webhook setup
- [ ] Can push code and see auto-deploy
- [ ] Slack notifications working
- [ ] Backups configured
- [ ] Security groups locked down
- [ ] Team trained on process

---

## 🎓 Learning Resources

**Inside Project:**
- Read: `JENKINS_COMPLETE_SUMMARY.md`
- Read: `JENKINS_ARCHITECTURE.md`
- Study: Updated `Jenkinsfile`
- Reference: `JENKINS_AUTOMATION_GUIDE.md`

**External:**
- Jenkins Docs: https://www.jenkins.io/doc/
- AWS EKS: https://docs.aws.amazon.com/eks/
- Docker: https://docs.docker.com/

---

**You're ready for professional CI/CD automation! 🚀**

Keep this card handy for quick reference!

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

