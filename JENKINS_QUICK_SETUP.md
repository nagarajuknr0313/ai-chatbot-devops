# Quick Jenkins Setup Guide

## 1️⃣ Access Jenkins

**Open your browser:** http://3.26.175.20:8080

**Paste this password:** `bed8f38db53948098d488c86dda6f410`

---

## 2️⃣ Complete Initial Setup

### Welcome Page
- Click **"Install suggested plugins"**
- Wait 5-10 minutes for plugins to install

### Create First Admin User
- Username: `admin`
- Password: (choose strong password, e.g., `Jenkins@123`)
- Full Name: (optional)
- Email: (optional)
- Click **"Save and Continue"**

### Instance Configuration
- Jenkins URL should be: `http://3.26.175.20:8080/`
- Click **"Save and Finish"**

### You're now on the Jenkins Dashboard! ✅

---

## 3️⃣ Add AWS Credentials

1. Top left menu → **Manage Jenkins**
2. Click **"Manage Credentials"**
3. Under "Stores scoped to Jenkins" → Click **"Jenkins"**
4. Upper right → **"Global credentials"**
5. Left menu → **"Add Credentials"**

**In the form:**
- **Kind:** Choose "AWS Credentials"
- **ID:** `aws-credentials`
- **Description:** AWS Credentials for ECR and EKS
- **Access Key ID:** _(paste your AWS access key)_
- **Secret Access Key:** _(paste your AWS secret key)_
- **Click "Create"**

**If you don't have AWS credentials:**
1. Go to AWS Console
2. IAM → Users → Select your user
3. Security credentials → Create access key
4. Copy both values

---

## 4️⃣ Create Pipeline Job

1. Jenkins home → **+ New Item** (top left)
2. **Item name:** `ai-chatbot-deploy`
3. **Type:** Choose **"Pipeline"**
4. Click **"OK"**

**In the Pipeline configuration:**
- Scroll down to **"Pipeline"** section
- **Definition:** "Pipeline script from SCM"
- **SCM:** "Git"
- **Repository URL:** (copy from below)
- **Credentials:** 
  - If private repo: Select GitHub credentials
  - If public repo: Leave blank
- **Branch:** `*/main`
- **Script Path:** `Jenkinsfile`

```
Repository URL (change USERNAME):
https://github.com/USERNAME/ai-chatbot-devops.git
```

5. Click **"Save"**

---

## 5️⃣ Test the Pipeline

1. On your job page → **"Build Now"**
2. Watch the build in real-time:
   - Click on the build (should see #1)
   - Click **"Console Output"**
   - Watch logs as it builds, pushes, and deploys

**Expected output:**
```
✅ Checking out branch: main
🔨 Building backend image
🔨 Building frontend image
🚀 Pushing images to ECR
📋 Deploying to EKS cluster
✅ All deployments are healthy!
```

---

## 6️⃣ Setup GitHub Webhook (Optional)

If you want auto-triggers when you push code:

**In your GitHub repo:**

1. Settings → **Webhooks** → **Add webhook**
2. **Payload URL:** `http://3.26.175.20:8080/github-webhook/`
3. **Content type:** `application/json`
4. Check `push events` and `pull request` events
5. Click **"Add webhook"**

Now when you push to GitHub, Jenkins will automatically build! 🚀

---

## 🔍 Troubleshooting

### Jenkins won't load
```bash
# SSH to instance
ssh -i "path/to/jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Check if Jenkins container is running
sudo docker ps | grep jenkins

# View logs
sudo docker logs -f jenkins

# Start if stopped
sudo docker start jenkins
```

### Build fails with "docker not found"
```bash
# SSH to instance
ssh -i "path/to/jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Check Docker
sudo docker ps

# Give Jenkins permission
sudo usermod -a -G docker jenkins
```

### "AWS credentials not found"
- Verify credentials added to Jenkins (Manage Credentials)
- Check credential ID matches in Jenkinsfile (should be `aws-credentials`)
- Verify Access Key ID and Secret are correct

### Build fails with "kubectl: command not found"
```bash
# SSH to instance and check
ssh ec2-user@3.26.175.20

kubectl version --client
# If not found, run:
# curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.24.7/2022-10-31/bin/linux/amd64/kubectl
# chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

---

## 📊 Useful Jenkins Links

Once logged in:

| Link | Purpose |
|------|---------|
| `/manage` | Manage Jenkins settings |
| `/credentials` | View all credentials |
| `/pluginManager` | Install/update plugins |
| `/job/{job-name}/lastBuild/console` | View last build logs |

---

## ✅ Verification Commands

Run these on the Jenkins EC2 to verify everything:

```bash
# SSH in
ssh -i "path/to/jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Check Docker
sudo docker --version
sudo docker ps

# Check kubectl  
kubectl version --client
kubectl get nodes

# Check AWS CLI
aws --version
aws sts get-caller-identity
```

---

## 🎉 You're Ready!

Once you've:
1. ✅ Completed Jenkins setup
2. ✅ Added AWS credentials
3. ✅ Created pipeline job
4. ✅ Tested with "Build Now"

**You can push your code to GitHub and the pipeline will auto-deploy!** 🚀
