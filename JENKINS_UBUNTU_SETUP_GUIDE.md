# Jenkins on Ubuntu 22.04 LTS - Complete Setup Guide

## Why Ubuntu Instead of Amazon Linux?

✅ **Advantages:**
- **Better Java Support**: Java 21 readily available in standard repositories
- **Faster Updates**: Ubuntu has frequent package updates with latest versions
- **No Version Conflicts**: Java compatibility issues largely avoided
- **Standard Tools**: More familiar package manager (apt) for most developers
- **Community Support**: More tutorials and examples for Jenkins + Ubuntu

## Prerequisites

- AWS Account with EC2 permissions
- PowerShell with AWS Tools for PowerShell installed
- SSH key pair (`jenkins-key`)
- VPC and Subnet IDs (or will use default)

## Step 1: Launch Ubuntu EC2 Instance

### Option A: Automatic Launch (Recommended)

Run the PowerShell script:

```powershell
# Navigate to scripts directory
cd d:\AI Work\ai-chatbot-devops\scripts

# Run the launch script
.\launch-jenkins-ubuntu-ec2.ps1
```

**What this does:**
- Finds the latest Ubuntu 22.04 LTS AMI
- Creates a new security group with SSH, Jenkins, and Agent ports
- Launches t3.medium instance
- Provides SSH connection details
- Saves instance information to `jenkins-ubuntu-instance.txt`

**Output Example:**
```
✅ Jenkins Ubuntu instance created successfully!

📋 Instance Details:
   Instance ID: i-0a1b2c3d4e5f6g7h8
   Public IP: 54.123.45.67
   Private IP: 10.0.11.42
   SSH Username: ubuntu (not ec2-user)

🔑 SSH Command:
   ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key.pem" ubuntu@54.123.45.67
```

### Option B: Manual Launch via AWS Console

If you prefer manual setup:
1. Go to EC2 → Instances → Launch Instance
2. **AMI**: Search for "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04" and select latest
3. **Instance Type**: t3.medium
4. **Network**: Select your VPC and subnet
5. **Security Group**: Create with inbound rules:
   - SSH (22) from your IP
   - HTTP (80) from your IP
   - TCP 8080 (Jenkins) from your IP
   - TCP 50000 (Jenkins agents) from your IP
6. **Key Pair**: Select or create `jenkins-key`
7. Launch and note the public IP

## Step 2: Connect via SSH

Wait 30 seconds after instance launch, then connect:

```bash
# Using SSH (from Windows PowerShell or WSL)
ssh -i "path/to/jenkins-key.pem" ubuntu@<public-ip>

# Example:
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key.pem" ubuntu@54.123.45.67
```

**Note**: User is `ubuntu`, not `ec2-user` (this is different from Amazon Linux!)

Once connected, you should see:
```
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 6.1.0-...)
ubuntu@ip-10-0-11-42:~$
```

## Step 3: Run Jenkins Setup Script

Inside the SSH session:

```bash
# Create setup directory if needed
mkdir -p ~/

# Copy setup script (you can also manually create it)
cat > ~/setup-jenkins-ubuntu.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "   Jenkins Setup for Ubuntu 22.04 LTS"
echo "=========================================="
echo ""

echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

echo ""
echo "☕ Installing Java 21..."
sudo apt-get install -y default-jdk

echo ""
echo "✓ Verifying Java installation..."
java -version

echo ""
echo "📚 Adding Jenkins repository..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
sudo sh -c 'echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list' > /dev/null
sudo apt-get update

echo ""
echo "🚀 Installing Jenkins..."
sudo apt-get install -y jenkins

echo ""
echo "⚙️  Starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

echo ""
echo "⏳ Waiting for Jenkins to initialize (30 seconds)..."
sleep 30

echo ""
echo "🔑 Jenkins Initial Admin Password:"
echo "=========================================="
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "=========================================="

INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "✅ Jenkins setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Open Jenkins in your browser: http://$INSTANCE_IP:8080"
echo "2. Paste the initial admin password above"
echo "3. Choose 'Install suggested plugins'"
echo "4. Create first admin user"
echo ""
EOF

# Make script executable
chmod +x ~/setup-jenkins-ubuntu.sh

# Run the script
bash ~/setup-jenkins-ubuntu.sh
```

**What happens:**
- ⏱️ Script takes ~3-5 minutes
- Updates all system packages
- Installs Java 21 (latest stable)
- Adds Jenkins repository
- Installs Jenkins LTS
- Starts Jenkins service on port 8080
- Outputs initial admin password (save this!)

**Expected Output:**
```
✅ Jenkins setup complete!

🔑 Jenkins Initial Admin Password:
==========================================
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
==========================================

📋 Next Steps:
1. Open Jenkins in your browser: http://54.123.45.67:8080
2. Paste the initial admin password above
3. Choose 'Install suggested plugins'
```

## Step 4: Access Jenkins Web UI

1. Open browser: `http://<public-ip>:8080`
   - Example: `http://54.123.45.67:8080`

2. Paste the initial admin password from Step 3

3. Click "Continue" → "Install suggested plugins"

4. Create first admin user:
   - Username: `admin` (or your preference)
   - Password: (choose a strong password)
   - Full name: (optional)
   - Email: (optional)

5. Jenkins dashboard appears → Ready to configure!

## Step 5: Configure Jenkins (Optional)

### Add AWS Credentials

1. Manage Jenkins → Manage Credentials
2. Click "Jenkins" → "Global credentials"
3. Add Credentials → AWS Credentials
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key

### Create Pipeline Job

1. New Item → Pipeline
2. Name: `ai-chatbot-deploy`
3. Pipeline → Definition: "Pipeline script from SCM"
4. SCM: Git
5. Repository URL: `https://github.com/your-username/ai-chatbot-devops.git`
6. Script Path: `Jenkinsfile`
7. Save

### Setup GitHub Webhook (Optional)

1. GitHub → Repository Settings → Webhooks
2. Add webhook
3. Payload URL: `http://<public-ip>:8080/github-webhook/`
4. Content type: `application/json`
5. Events: "Push events" and "Pull requests"

## Troubleshooting

### SSH Connection Issues

```bash
# If SSH times out or refuses connection:
# 1. Check security group has SSH (22) open to your IP
# 2. Verify instance is running (AWS console)
# 3. Wait 60 seconds after launch before trying SSH
# 4. Verify key file permissions:
ls -la d:\AI\ Work\ai-chatbot-devops\keys\jenkins-key.pem
# Should show: -rw-r--r--
```

### Jenkins Not Accessible on Port 8080

```bash
# SSH into instance, then:

# Check if Jenkins is running
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -50 /var/log/jenkins/jenkins.log

# Check if port 8080 is listening
sudo netstat -tuln | grep 8080
```

### Java Version Issues

```bash
# Verify Java is installed and correct version
java -version
# Should show: openjdk version "21.0.x" or higher

# If Java is missing or old:
sudo apt-get install -y default-jdk
```

## Java Versions on Ubuntu 22.04

| Java Version | Package | Status |
|---|---|---|
| Java 21 | `default-jdk` | ✅ Recommended (latest) |
| Java 17 | `openjdk-17-jdk` | ✅ Available |
| Java 11 | `openjdk-11-jdk` | ✅ Available |

## Important Notes

⚠️ **Security:**
- Security group should restrict IPs to your actual IP, not 0.0.0.0/0
- Use strong password for Jenkins admin user
- Enable "Prevent Cross Site Request Forgery (CSRF)" in Jenkins

💡 **Performance:**
- t3.medium has 2 vCPU and 4GB RAM (sufficient for dev/test)
- For production, use t3.large or larger

🔄 **Backups:**
- Jenkins configuration stored in `/var/lib/jenkins/`
- Consider periodic backups before major changes

## Next Steps After Jenkins is Ready

1. ✅ Access Jenkins UI at http://<public-ip>:8080
2. ✅ Create admin user
3. ✅ Add AWS credentials
4. ✅ Create pipeline job from Jenkinsfile
5. ✅ Configure GitHub webhook
6. ✅ Test by pushing code to GitHub

## Common Commands (Inside SSH Session)

```bash
# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs (last 50 lines)
sudo tail -50 /var/log/jenkins/jenkins.log

# Restart Jenkins
sudo systemctl restart jenkins

# Stop Jenkins
sudo systemctl stop jenkins

# Check Java version
java -version

# Check open ports
sudo netstat -tuln | grep LISTEN
```

## Reference Links

- **Jenkins Official**: https://www.jenkins.io/
- **Ubuntu Package Search**: https://packages.ubuntu.com/
- **AWS EC2 Documentation**: https://docs.aws.amazon.com/ec2/
- **Jenkins Pipeline Guide**: https://www.jenkins.io/doc/book/pipeline/

---

**Questions?** Check Jenkins logs or system messages using the commands above.
