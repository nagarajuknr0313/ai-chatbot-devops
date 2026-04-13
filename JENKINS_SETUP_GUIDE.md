# Jenkins CI/CD Pipeline Setup Guide

## 🚀 Quick Start

### Jenkins Access
- **URL:** http://localhost:8080
- **Initial Admin Password:** `74b2c2a45d0643238faaaf43c5347950`
- **Status:** Running in Docker on port 8080

---

## Step 1: Initial Jenkins Setup

### 1.1 Access Jenkins UI
Open browser and navigate to: http://localhost:8080

### 1.2 Unlock Jenkins
1. Paste the initial admin password: `74b2c2a45d0643238faaaf43c5347950`
2. Click "Continue"

### 1.3 Install Suggested Plugins
- Select "Install suggested plugins" option
- Wait for plugins to install (5-10 minutes)
- **Standard plugins installed:**
  - Pipeline
  - Git
  - Docker
  - Email Extension
  - Mailer

### 1.4 Create First Admin User
Fill in the form:
- Username: `admin` (or your preference)
- Password: Create a secure password
- Full name: `Administrator`
- Email: `admin@localhost` (or your email)
- Click "Save and Continue"

### 1.5 Configure Jenkins URL
- Keep default: `http://localhost:8080/`
- Click "Save and Finish"

---

## Step 2: Install Required Plugins

After initial setup, install additional plugins for Docker and Kubernetes:

### 2.1 Navigate to Plugin Manager
1. Click "Manage Jenkins" (top left)
2. Click "Manage Plugins"
3. Go to "Available plugins" tab

### 2.2 Install Docker Pipeline Plugin
Search for: **Docker Pipeline**
- Check the checkbox
- Click Install without restart

### 2.3 Install Other Recommended Plugins
Search and install:
- [ ] **Docker plugin** - Docker integration
- [ ] **Kubernetes plugin** - Kubernetes support
- [ ] **Pipeline: GitHub** - GitHub integration
- [ ] **Timestamper** - Add timestamps to console output
- [ ] **Log Parser** - Parse and highlight log output

### 2.4 Restart Jenkins
1. Click "Manage Jenkins"
2. Click "Restart Jenkins"
3. Jenkins will restart (takes ~1 minute)
4. Navigate back to http://localhost:8080

---

## Step 3: Configure Docker for Jenkins

### 3.1 Grant Jenkins Docker Access
Run in PowerShell:
```powershell
docker exec -u root jenkins usermod -aG docker jenkins
```

### 3.2 Verify Docker Socket Connection
```powershell
docker exec jenkins docker ps
```
Should return: `Cannot connect to Docker daemon` message if needed, or successful container list

---

## Step 4: Configure Credentials

### 4.1 Add Docker Hub Credentials (Optional)
For pushing images to Docker Hub, add credentials:

1. Click "Manage Jenkins" > "Manage Credentials"
2. Click "System" > "Global credentials (unrestricted)"
3. Click "Add Credentials" (left side)
4. Select "Username with password"
5. Fill in:
   - **Username:** Your Docker Hub username
   - **Password:** Your Docker Hub access token
   - **ID:** `docker-hub-creds`
   - **Description:** Docker Hub Credentials
6. Click "Create"

### 4.2 Add GitHub Credentials (Optional)
If using GitHub integration:

1. Click "Add Credentials"
2. Select "Username with password" or "SSH Key"
3. GitHub Personal Access Token:
   - **Username:** `git` or your GitHub username
   - **Password:** GitHub personal access token
   - **ID:** `github-token`
4. Click "Create"

---

## Step 5: Create Pipeline Job

### 5.1 Create New Job
1. Click "New Item" (left menu)
2. Enter job name: `ai-chatbot-pipeline`
3. Select "Pipeline"
4. Click "OK"

### 5.2 Configure Job

#### General Section
- [ ] Check "GitHub project"
  - If using GitHub: Enter project URL
  
- [ ] Check "This project is parameterized"
  - Add parameters for flexibility (optional):
    - String parameter: BUILD_ENV (default: production)
    - String parameter: REGISTRY (default: docker.io)

#### Build Triggers
- [ ] Check "GitHub hook trigger for GITScm polling"
  - (if using GitHub webhooks)
  
- [ ] OR Check "Poll SCM"
  - Schedule: `H/30 * * * *` (poll every 30 minutes)

#### Pipeline Section
**Definition:** Select "Pipeline script from SCM"

1. **SCM:** Git
   - Repository URL: `https://github.com/YOUR_USERNAME/ai-chatbot-devops.git`
   - Branch: `*/main` or `*/master`
   - Credentials: Select GitHub credentials (if private repo)

2. **Script Path:** `Jenkinsfile`

Click "Save"

---

## Step 6: Configure Docker Access in Jenkins Container

For the pipeline to build Docker images, Jenkins needs Docker access:

### 6.1 Edit Jenkins Docker Compose (if not already done)
File: `jenkins/docker-compose.yml`

Add Docker socket mount:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - /usr/bin/docker:/usr/bin/docker:ro
  - jenkins_data:/var/jenkins_home
```

### 6.2 Restart Jenkins with Docker Access
```powershell
cd jenkins
docker-compose down
docker-compose up -d
```

---

## Step 7: Test the Pipeline

### 7.1 Manual Trigger
1. Navigate to your job: `ai-chatbot-pipeline`
2. Click "Build Now" (left menu)
3. Click on build number in "Build History" (left side)
4. Click "Console Output" to view logs

### 7.2 Expected Pipeline Stages

The Jenkinsfile defines 6 stages:

```
✓ Checkout         - Git repository cloned
✓ Build Backend    - docker build backend image
✓ Build Frontend   - docker build frontend image
✓ Push to Registry - docker push images to registry
✓ Deploy to K8s    - kubectl set image for deployments
✓ Health Check     - Verify pod status
```

### 7.3 Monitor Build
- Green = Success ✅
- Red = Failed ❌
- Yellow = In Progress ⏳

---

## Step 8: Configure Environment Variables

In Jenkins Job Configuration:

### 8.1 Add Credentials to Pipeline
1. Go to Job > Configure
2. Scroll to "Pipeline" section
3. In the pipeline script, add environment block:

```groovy
environment {
    REGISTRY = credentials('docker-registry')
    REGISTRY_CREDS = credentials('docker-hub-creds')
    DOCKER_LOGIN = credentials('docker-hub-creds')
}
```

Or use Groovy within pipeline script for dynamic values.

---

## Step 9: Webhook Configuration (GitHub)

For automatic pipeline triggers on push:

### 9.1 GitHub Repository Settings
1. Navigate to your GitHub repo
2. Settings > Webhooks > Add webhook
3. Configuration:
   - **Payload URL:** `http://your-jenkins-url:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Push events
   - **Active:** ✓ Checked

### 9.2 Jenkins Configuration
1. Job > Configure
2. Build Triggers > Check "GitHub hook trigger for GITScm polling"
3. Save

Now every push to main branch will trigger the pipeline automatically.

---

## Step 10: View Pipeline Execution

### 10.1 Monitor Build in Real-Time
1. Navigate to Job > Latest Build Number
2. Click "Console Output"
3. Watch logs in real-time as pipeline progresses

### 10.2 View Pipeline Visualization
Jenkins displays:
- Each stage as a box
- Green/Red/Yellow status
- Execution time per stage
- Detailed logs for each stage

### 10.3 Troubleshooting Failed Builds

If build fails:
1. Check Console Output for errors
2. Common issues:
   - Docker not accessible: Run docker commands in Jenkins container
   - Missing credentials: Configure in Credentials section
   - Image not found: Verify Dockerfile paths in Jenkinsfile
   - Registry auth failed: Check Docker Hub credentials

---

## Jenkinsfile Overview

Location: `Jenkinsfile` (project root)

### Pipeline Stages Explained

```groovy
pipeline {
    agent any
    
    environment {
        REGISTRY = 'docker.io'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            // Clone repository from GitHub
        }
        
        stage('Build Backend') {
            // Build FastAPI Docker image
            // Dockerfile: backend/Dockerfile
        }
        
        stage('Build Frontend') {
            // Build React Docker image
            // Dockerfile: frontend/Dockerfile
        }
        
        stage('Push to Registry') {
            // Push images to Docker Hub
            // Requires credentials
        }
        
        stage('Deploy to Kubernetes') {
            // Update Kubernetes deployment with new images
            // kubectl set image deployment/backend image=...
        }
        
        stage('Health Check') {
            // Verify pods are running
            // Check pod status and readiness
        }
    }
}
```

---

## Common Jenkins Configurations

### Enable Email Notifications
1. Manage Jenkins > Configure System
2. E-mail Notification
3. SMTP Server: `smtp.gmail.com`
4. Default suffix: `@gmail.com`
5. Click "Test configuration"

### Set Timezone
1. Manage Jenkins > Configure System
2. System Time Zone: `UTC` or your timezone
3. Save

### Disable CSRF Protection (Development Only)
1. Manage Jenkins > Configure Global Security
2. Uncheck "Prevent Cross Site Request Forgery exploits"
3. **Note:** For production, keep CSRF enabled

---

## Useful Jenkins Commands

### View Jenkins Logs
```powershell
docker logs jenkins
docker logs -f jenkins      # Follow logs in real-time
```

### Access Jenkins Container Shell
```powershell
docker exec -it jenkins bash
```

### Verify Docker in Jenkins
```powershell
docker exec jenkins docker ps
docker exec jenkins docker version
```

### Check Jenkins Version
```powershell
docker inspect jenkins | grep -i image
```

---

## Next Steps After Setup

1. **Trigger First Build**
   - Click "Build Now" on pipeline job
   - Monitor console output
   - Verify all stages complete

2. **Enable GitHub Webhook** (Optional)
   - Set up automatic triggers on push
   - Reduces manual build triggering

3. **Configure Notifications** (Optional)
   - Email on build completion
   - Slack integration
   - GitHub PR comments

4. **Scale Pipeline** (Advanced)
   - Multiple pipeline jobs for different branches
   - Conditional deployments (prod vs staging)
   - Parallel stage execution

5. **Monitor and Optimize**
   - Review build logs
   - Optimize Docker build cache
   - Improve pipeline performance

---

## Troubleshooting

### Problem: "Cannot connect to Docker daemon"
**Solution:**
```powershell
docker exec -u root jenkins usermod -aG docker jenkins
docker exec jenkins chmod 666 /var/run/docker.sock
docker-compose restart jenkins
```

### Problem: "Git repository not found"
**Solution:**
- Verify GitHub credentials are configured
- Check repository URL is correct
- Ensure SSH key or token is valid

### Problem: Pipeline stages failing
**Solution:**
1. Check Console Output for detailed error
2. Verify all images and files exist
3. Test Docker commands manually:
   ```powershell
   docker exec jenkins docker build -f backend/Dockerfile -t test .
   ```

### Problem: Unable to access Jenkins at localhost:8080
**Solution:**
```powershell
docker ps | grep jenkins
docker logs jenkins
docker-compose -f jenkins/docker-compose.yml restart
```

---

## Performance Tips

1. **Enable Docker Layer Caching**
   - Add `--cache-from` to docker build commands
   - Significantly speeds up subsequent builds

2. **Use Docker Registry Cache**
   - Push images after successful build
   - Reuse base images from registry

3. **Parallel Stages**
   - Run backend and frontend builds in parallel
   - Reduces overall pipeline execution time

4. **Pipeline Performance**
   - Target build time: 3-5 minutes
   - If exceeding 10 minutes, optimize stages

---

## Security Considerations

### For Production:
- [ ] Enable CSRF protection
- [ ] Use HTTPS for Jenkins URL
- [ ] Implement Jenkins user authentication
- [ ] Mask sensitive data in logs
- [ ] Use Jenkins credentials for all secrets
- [ ] Enable audit logging
- [ ] Regular Jenkins updates
- [ ] Backup Jenkins configuration

### For Local Development:
- Use local credentials for testing
- Enable webhook only when needed
- Use HTTP (not HTTPS) for localhost
- Simple authentication is sufficient

---

## Useful Resources

- Jenkins Documentation: https://www.jenkins.io/doc/
- Pipeline Syntax Guide: http://localhost:8080/pipeline-syntax/
- Docker Integration: https://www.jenkins.io/doc/book/pipeline/docker/
- Kubernetes Plugin: https://plugins.jenkins.io/kubernetes/

---

## Quick Reference Commands

```powershell
# View Jenkins status
docker ps -a | grep jenkins

# View Jenkins logs
docker logs jenkins

# Get initial password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Restart Jenkins
docker-compose -f jenkins/docker-compose.yml restart

# Access Jenkins container
docker exec -it jenkins bash

# View Jenkins home directory
docker exec jenkins ls -la /var/jenkins_home

# Clear Jenkins cache
docker exec jenkins rm -rf /var/jenkins_home/workspace/*
```

---

## Configuration Checklist

- [ ] Jenkins UI accessible at http://localhost:8080
- [ ] Initial admin user created
- [ ] Suggested plugins installed
- [ ] Docker Pipeline plugin installed
- [ ] Kubernetes plugin installed
- [ ] Docker access configured for Jenkins
- [ ] GitHub credentials added (if needed)
- [ ] Docker Hub credentials added (if needed)
- [ ] Pipeline job created: `ai-chatbot-pipeline`
- [ ] Pipeline job configured with Git repo and Jenkinsfile
- [ ] Build triggered manually and monitored
- [ ] All pipeline stages completed successfully
- [ ] Console output shows "SUCCESS" or similar
- [ ] GitHub webhook configured (optional)
- [ ] Email notifications configured (optional)

---

## Success Indicators

✅ **Pipeline Configured When:**
- Jenkins UI is accessible and responsive
- Pipeline job created and visible in Jenkins dashboard
- Manual build can be triggered
- All 6 pipeline stages appear in execution
- Build completes with success status
- Docker images are built successfully
- Container logs show no critical errors

✅ **Ready for Production When:**
- Multiple successful builds executed
- GitHub webhook triggers builds automatically
- Kubernetes deployment updates with new images
- Health checks verify pod status
- Pipeline execution time is acceptable (~3-5 minutes)
- Error handling and rollback procedures tested

---

**Last Updated:** April 14, 2026
**Status:** Jenkins configured and ready for CI/CD pipeline execution

