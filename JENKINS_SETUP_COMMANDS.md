# Jenkins Setup - Exact Commands & Steps

## 🎯 Current Status

✅ Jenkinsfile: Valid and correct  
✅ Docker images built and pushed to ECR  
✅ EKS cluster running with 3 backend + 2 frontend pods  
✅ Jenkins Docker instance running at 3.26.175.20:8080  
✅ AWS values verified and correct  

---

## 📝 Step-by-Step Setup

### STEP 1: Open Jenkins in Browser
```
URL: http://3.26.175.20:8080
Initial Password: bed8f38db53948098d488c86dda6f410
```

**What you'll see:**
- "Welcome to Jenkins" page with unlock screen
- Paste password above
- Click Continue

---

### STEP 2: Install Suggested Plugins
**What to do:**
- Click "Install suggested plugins"
- Wait 5-10 minutes for installation
- Page will redirect automatically

**You'll see progress:**
- Installing Git
- Installing Docker
- Installing Pipeline plugins
- Installing Kubernetes plugins
- Installing AWS plugins
- etc.

---

### STEP 3: Create First Admin User

**Fill this form:**
```
Username:     admin
Password:     YourStrongPassword123!  (save this)
Full name:    Admin User (optional)
Email:        your-email@example.com (optional)
```

Click "Save and Continue"

---

### STEP 4: Instance Configuration

**You'll see pre-filled URL:**
```
Jenkins URL: http://3.26.175.20:8080/
```

Just click "Save and Finish"

---

### STEP 5: Add AWS Credentials

**Navigate:**
```
Dashboard → Manage Jenkins → Manage Credentials
```

**In Credentials page:**
```
Click: Jenkins (under "Stores scoped to Jenkins")
Click: Global credentials (in left menu)
Click: Add Credentials (top right)
```

**Fill this form:**
```
Kind:                  AWS Credentials (select from dropdown)
ID:                    aws-credentials
Description:           AWS Credentials for ECR and EKS access
Access Key ID:         ??? (from your AWS account)
Secret Access Key:     ??? (from your AWS account)
```

Click "Create"

**If you don't have AWS credentials:**
1. Go to: https://console.aws.amazon.com/iam/
2. Users → Select your user
3. Security credentials tab
4. Create access key (if none exist)
5. Copy Access Key ID and Secret

---

### STEP 6: Create Pipeline Job

**Navigate:**
```
Jenkins Home → New Item (top left)
```

**Fill form:**
```
Item name:     ai-chatbot-deploy
Type:          Pipeline (click it)
```

Click "OK"

**In configuration page, scroll to "Pipeline" section:**
```
Definition:    Pipeline script from SCM
SCM:           Git
Repository URL: https://github.com/{YOUR_USERNAME}/ai-chatbot-devops.git
Credentials:   (leave blank if public, or select GitHub token if private)
Branch:        */main
Script Path:   Jenkinsfile
```

Click "Save"

---

### STEP 7: Test Pipeline

**On the job page:**
```
Click "Build Now" (left menu)
```

**Watch build progress:**
```
Click on the build number (e.g., #1)
Click "Console Output"
Watch logs as it:
  1. Checks out code
  2. Builds backend image
  3. Builds frontend image
  4. Pushes to ECR
  5. Deploys to EKS
  6. Verifies health
```

**Expected final output:**
```
✅ All deployments are healthy!
Pipeline executed successfully!
```

---

### STEP 8: (Optional) Configure GitHub Webhook

**In your GitHub repository:**
```
Settings → Webhooks → Add webhook
```

**Fill:**
```
Payload URL:       http://3.26.175.20:8080/github-webhook/
Content type:      application/json
Events:            ✅ Push events
                   ✅ Pull requests
Active:            ✅ Checked
```

Click "Add webhook"

**Now Jenkins will auto-build whenever you push!**

---

## 🚀 Push Your Code

Once pipeline successfully builds and deploys:

```powershell
cd "d:\AI Work\ai-chatbot-devops"

# Check status
git status

# Stage all changes
git add .

# Commit
git commit -m "Configure Jenkins CI/CD pipeline with Docker and EKS integration"

# Push to main
git push origin main
```

---

## ⚡ Quick Troubleshooting

### Jenkins not loading?
```bash
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem" ec2-user@3.26.175.20
sudo docker logs jenkins
sudo docker restart jenkins
```

### Build fails with "docker: command not found"?
```bash
ssh ec2-user@3.26.175.20
sudo docker ps  # Should work
```

### Build fails with "AWS credentials not found"?
```
Check:
1. Credentials added to Jenkins? (Manage Credentials)
2. ID is "aws-credentials"? (must match exactly)
3. Access Key and Secret are correct?
```

### Build fails with "kubectl not found"?
```bash
ssh ec2-user@3.26.175.20
kubectl version --client
# If fails, install kubectl
```

---

## ✅ Verification Commands

**On your local machine:**

```powershell
# Verify Git
git --version

# Check remote
git remote -v
# Should show:
# origin  https://github.com/YOUR_USERNAME/ai-chatbot-devops.git (fetch)
# origin  https://github.com/YOUR_USERNAME/ai-chatbot-devops.git (push)

# Check status
git status
# Should show nothing or only local uncommitted changes
```

**On EC2 (via SSH):**

```bash
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Verify Docker
sudo docker --version
sudo docker ps

# Verify kubectl
kubectl version --client
kubectl get nodes

# Verify AWS CLI
aws --version
aws sts get-caller-identity
```

---

## 📊 Final Checklist

- [ ] Jenkins dashboard opens at http://3.26.175.20:8080
- [ ] Initial setup wizard completed
- [ ] Admin user created and can login
- [ ] AWS credentials added (ID: aws-credentials)
- [ ] Pipeline job "ai-chatbot-deploy" created
- [ ] "Build Now" completed successfully
- [ ] Backend image in ECR (new tag)
- [ ] Frontend image in ECR (new tag)
- [ ] EKS pods restarted and healthy
- [ ] GitHub webhook configured (optional)
- [ ] Git status is clean
- [ ] Ready to push to main branch

---

## 🎉 After Push

Once you push to GitHub:

1. **Webhook triggers** Jenkins automatically (if configured)
2. **Pipeline runs** automatically on every push
3. **New code deployed** to EKS automatically
4. **Front-end updates** visible in browser
5. **Backend API** serves new endpoints immediately

---

## 🔗 Important URLs & Info

```
Jenkins URL:      http://3.26.175.20:8080
EC2 Instance:     3.26.175.20
Instance ID:      i-0c4a5d471a82cba69
SSH Command:      ssh -i "jenkins-key-fixed.pem" ec2-user@3.26.175.20

AWS Region:       ap-southeast-2
AWS Account:      868987408656
EKS Cluster:      ai-chatbot-cluster
K8s Namespace:    chatbot
```

---

## 💾 Save This For Later

```
Jenkins Initial Admin Password: bed8f38db53948098d488c86dda6f410
(Only needed if you reset Jenkins)

AWS Credentials ID: aws-credentials
(Used in Jenkins for ECR and EKS access)

Key File: d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem
(For SSH access to EC2)
```

---

**Status: ✅ READY FOR JENKINS SETUP AND CODE PUSH**

Follow steps 1-6 above, test in step 7, then push code!
