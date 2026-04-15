# 🚀 EC2 Jenkins Setup - Step by Step Guide

## Your Setup Plan (10 Steps, ~30 minutes total)

### **Step 1: Launch EC2 Instance**
### **Step 2: Configure Security & Access**  
### **Step 3: SSH into EC2**
### **Step 4: Run Automated Setup Script**
### **Step 5: Access Jenkins UI**
### **Step 6: Configure Jenkins**
### **Step 7: Add AWS Credentials**
### **Step 8: Create Pipeline Job**
### **Step 9: Setup GitHub Webhook**
### **Step 10: Test with Code Push**

---

## 📋 STEP 1: Launch EC2 Instance (5 minutes)

### Option A: Using AWS Console (Easiest)

1. **Go to AWS Console**
   - Navigate to: https://console.aws.amazon.com/ec2/

2. **Click "Launch Instances"**
   - Instance name: `jenkins-controller`
   - AMI: `Amazon Linux 2` (free tier eligible)
   - Instance type: `t3.medium` ($0.0376/hour ≈ $27/month)

3. **Key Pair**
   - Create new or select existing
   - Download `.pem` file (save securely!)
   - **Example:** `jenkins-key.pem`

4. **Network Settings**
   - VPC: Default
   - Auto-assign public IP: ✅ Enable
   - Security group: Create new
     - Name: `jenkins-security-group`

5. **Security Group Rules**
   - Inbound Rules:
     - Rule 1: SSH (22) from your IP
     - Rule 2: HTTP (8080) from your IP
     - Rule 3: Custom TCP (50000) from your IP (for agents later)
   
   - Outbound Rules:
     - Allow all (default)

6. **Storage**
   - Root volume: 20 GB minimum
   - Volume type: gp3
   - Delete on termination: ✅

7. **Review & Launch**
   - Click "Launch Instance"
   - Wait 30-60 seconds for instance to start

### **Get Your Instance Details**

Once launched:
```
Instance ID: i-xxxxxxxxx
Public IP: XXX.XXX.XXX.XXX (note this!)
Security Group: jenkins-security-group
Key Pair: jenkins-key.pem (save location)
```

---

## 🔐 STEP 2: Configure Security & Access

### **2.1 Restrict Security Group (IMPORTANT!)**

```
Go to EC2 → Security Groups → jenkins-security-group
Edit Inbound Rules:

Current: Allow from 0.0.0.0/0 (everywhere)
Change to: Your IP only

Example: 
SSH (22): Your.IP.Address/32
HTTP (8080): Your.IP.Address/32

Find your IP: https://www.whatismyip.com/
```

### **2.2 Set File Permissions for Key Pair**

```powershell
# On your Windows machine, after saving jenkins-key.pem:

cd C:\Users\YourUsername\Downloads
icacls jenkins-key.pem /inheritance:r /grant:r "$($env:USERNAME):(F)"

# Or in PowerShell:
$acl = Get-Acl "jenkins-key.pem"
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
  "FullControl",
  "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl "jenkins-key.pem" $acl
```

---

## 💻 STEP 3: SSH into EC2 Instance (2 minutes)

### **Using PowerShell**

```powershell
# 1. Open PowerShell
# 2. Navigate to where you saved jenkins-key.pem
cd C:\Users\YourUsername\Downloads

# 3. SSH into EC2
ssh -i jenkins-key.pem ec2-user@YOUR_EC2_PUBLIC_IP

# Example:
ssh -i jenkins-key.pem ec2-user@54.123.456.789

# 4. When asked "Are you sure you want to continue connecting?"
# Type: yes
```

**Expected Output:**
```
       __|  __|_  )
       _|  (     /   Amazon Linux 2
      ___|\___|___|

ec2-user@ip-172-31-0-123:~$ _
```

You're now inside the EC2 instance! ✅

---

## 🔧 STEP 4: Run Automated Setup Script (5-10 minutes)

### **Copy-Paste This Entire Command:**

```bash
#!/bin/bash
set -e

echo "======================================"
echo "🚀 Installing Jenkins on EC2"
echo "======================================"

# 1. Update system
echo "📦 Updating system packages..."
sudo yum update -y

# 2. Install Java (Required for Jenkins)
echo "☕ Installing Java 11..."
sudo yum install -y java-11-amazon-corretto

# 3. Install Jenkins
echo "🤖 Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins

# 4. Install Docker
echo "🐳 Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker jenkins

# 5. Install kubectl
echo "☸️  Installing kubectl..."
curl -o /tmp/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/

# 6. Install AWS CLI v2
echo "🌐 Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install

# 7. Start Jenkins
echo "🔥 Starting Jenkins..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo ""
echo "======================================"
echo "✅ Installation Complete!"
echo "======================================"
echo ""
echo "Get your initial admin password:"
echo ""
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "======================================"
```

### **How to Run:**

1. **Copy the entire script above** (from `#!/bin/bash` to the last line)
2. **Paste into terminal** where you SSH'd into EC2
3. **Press Enter**
4. **Wait 5-10 minutes** (it installs everything automatically)
5. **Copy the password** it shows at the end (you'll need this!)

**Example Output:**
```
✅ Installation Complete!

Get your initial admin password:

a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

======================================
```

🎉 **Jenkins installation complete!**

---

## 🌐 STEP 5: Access Jenkins UI (2 minutes)

**Once setup finishes:**

1. **Open Browser**
   ```
   http://YOUR_EC2_IP:8080
   
   Example: http://54.123.456.789:8080
   ```

2. **Paste Initial Password**
   - Get password from previous step
   - Click "Continue"

3. **Install Suggested Plugins**
   - Click "Install suggested plugins"
   - Wait 5-10 minutes

4. **Create First Admin User**
   ```
   Username: admin
   Password: YourSecurePassword
   Full Name: Administrator
   Email: your-email@example.com
   ```

5. **Configure Jenkins URL**
   - Keep default: `http://YOUR_EC2_IP:8080`
   - Click "Save and Finish"

✅ **Jenkins is now ready!**

---

## 🔑 STEP 6: Configure Jenkins (5 minutes)

### **6.1 Go to Manage Jenkins**

```
Jenkins UI → Manage Jenkins → Configure System
```

### **6.2 Configure GitHub Server** (Optional but recommended)

```
Under "GitHub" section:
- Check: "Manage hooks"
- Add GitHub Server:
  - Name: GitHub
  - API URL: https://api.github.com
  - Credentials: (skip for public repos)
```

### **6.3 Configure Email** (Optional)

```
Under "E-mail Notification":
- SMTP server: smtp.gmail.com
- Default user e-mail suffix: @gmail.com
```

**Save Configuration**

---

## 🔐 STEP 7: Add AWS Credentials to Jenkins (3 minutes)

### **7.1 Go to Manage Credentials**

```
Jenkins UI → Manage Jenkins → Manage Credentials
```

### **7.2 Add New Credentials**

1. **Click "Add Credentials"**

2. **Fill in Details:**
   ```
   Kind: AWS Credentials
   Scope: Global
   Access Key ID: Your AWS Access Key
   Secret Access Key: Your AWS Secret Key
   ID: aws-credentials
   Description: AWS credentials for ECR and EKS
   ```

3. **Find Your AWS Keys:**
   - Go to: AWS Console → IAM → Users → Your User
   - Security credentials tab
   - Create access key (if needed)
   - Copy Key ID and Secret Key

4. **Click "Create"**

✅ **AWS credentials saved!**

---

## 📱 STEP 8: Create Pipeline Job (3 minutes)

### **8.1 Create New Item**

```
Jenkins UI → New Item
```

### **8.2 Configure Job**

```
Job Name: chatbot-deployment-pipeline

Type: Pipeline

Pipeline Section:
- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: https://github.com/YOUR_USERNAME/ai-chatbot-devops.git
- Credentials: GitHub token (if private repo)
- Branch: main
- Script Path: Jenkinsfile
- Build Triggers: GitHub hook trigger for GITScm polling

Click: Save
```

### **8.3 Test Job**

```
Jenkins UI → Job → Build Now

Wait for build to complete
Check Console Output for any errors
```

✅ **Pipeline job created!**

---

## 🔗 STEP 9: Setup GitHub Webhook (3 minutes)

### **9.1 In Your GitHub Repository**

1. **Go to Settings**
   ```
   Your Repo → Settings → Webhooks
   ```

2. **Click "Add webhook"**

3. **Configure Webhook**
   ```
   Payload URL: http://YOUR_EC2_IP:8080/github-webhook/
   
   Example: http://54.123.456.789:8080/github-webhook/
   
   Content type: application/json
   
   Which events: Just the push event
   
   Active: ✅ Checked
   
   Click: Add webhook
   ```

✅ **Webhook active!** Green checkmark appears after first test.

---

## 🧪 STEP 10: Test with Code Push (5 minutes)

### **10.1 Make a Test Change**

```bash
# On your local machine:
cd d:\AI Work\ai-chatbot-devops

# Make a small change (e.g., add comment)
# Then:
git add .
git commit -m "Test Jenkins auto-deployment"
git push origin main
```

### **10.2 Watch Jenkins Build**

```
Go to Jenkins UI → Job → Build History

You should see:
1. New build triggered automatically
2. Build stages running
3. Docker images building
4. Images pushing to ECR
5. EKS deployment updating
6. Final status: SUCCESS ✅
```

### **10.3 Verify in EKS**

```powershell
# Check if pods restarted:
kubectl get pods -n chatbot

# Check new deployment:
kubectl get deployments -n chatbot
```

✅ **Full automation working!**

---

## 📊 Summary

| Step | Time | Status |
|------|------|--------|
| 1. Launch EC2 | 5 min | ⏳ |
| 2. Security config | 2 min | ⏳ |
| 3. SSH into EC2 | 2 min | ⏳ |
| 4. Run setup script | 5-10 min | ⏳ |
| 5. Access Jenkins UI | 2 min | ⏳ |
| 6. Configure Jenkins | 5 min | ⏳ |
| 7. Add AWS creds | 3 min | ⏳ |
| 8. Create pipeline job | 3 min | ⏳ |
| 9. Setup GitHub webhook | 3 min | ⏳ |
| 10. Test with push | 5 min | ⏳ |
| **TOTAL** | **~35 mins** | ⏳ |

---

## 🎉 After Setup

**You'll have:**
- ✅ Jenkins running 24/7 on EC2
- ✅ Automatic builds on every GitHub push
- ✅ Docker images built automatically
- ✅ Images pushed to ECR automatically
- ✅ EKS deployments updated automatically
- ✅ ~5-8 minutes from push to live production!

---

## 🆘 Troubleshooting

### **Can't SSH into EC2**
- Check security group allows SSH from your IP
- Check .pem file has correct permissions
- Try: `ssh -v` for verbose output

### **Jenkins won't start**
- SSH into EC2: `sudo systemctl status jenkins`
- Check logs: `sudo tail -f /var/log/jenkins/jenkins.log`
- Verify Java: `java -version`

### **Webhook not firing**
- Check GitHub webhook delivery (green check)
- Verify Jenkins URL is reachable from GitHub
- Check Jenkins firewall: `sudo firewall-cmd --list-all`

### **ECR push fails**
- Verify AWS credentials in Jenkins
- Check EC2 IAM role has ECR permissions
- Try: `aws sts get-caller-identity`

### **EKS deploy fails**
- Check kubectl config: `kubectl config view`
- Verify kubeconfig: `aws eks update-kubeconfig --region ap-southeast-2 --name ai-chatbot-cluster`
- Check pods: `kubectl get pods -n chatbot`

---

## 📝 Keep These Handy

**Your Jenkins URL:**
```
http://YOUR_EC2_IP:8080
```

**SSH Command:**
```
ssh -i jenkins-key.pem ec2-user@YOUR_EC2_IP
```

**Jenkins Admin:**
- Username: admin
- Password: (what you set)

**GitHub Webhook URL:**
```
http://YOUR_EC2_IP:8080/github-webhook/
```

---

**Ready to start? Begin with STEP 1! 🚀**
