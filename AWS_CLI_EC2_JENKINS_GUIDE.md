# AWS CLI EC2 Jenkins Launch - Quick Reference

## 📋 Prerequisites

Before running the script, make sure you have:

✅ **AWS CLI installed:**
```powershell
aws --version
```

✅ **AWS credentials configured:**
```powershell
aws sts get-caller-identity
```

Should show your AWS Account ID and User ARN

✅ **Correct region configured:**
```powershell
aws configure get region
```

Should show: `ap-southeast-2`

---

## 🚀 Launch EC2 with One Command

### **Option 1: Default Settings**

```powershell
cd d:\AI Work\ai-chatbot-devops
.\scripts\launch-jenkins-ec2.ps1
```

This will:
- Create key pair: `jenkins-key`
- Create security group: `jenkins-security-group`
- Launch instance type: `t3.medium`
- Use region: `ap-southeast-2`

### **Option 2: Custom Parameters**

```powershell
.\scripts\launch-jenkins-ec2.ps1 `
    -KeyName "my-jenkins-key" `
    -InstanceName "my-jenkins-server" `
    -InstanceType "t3.large" `
    -Region "ap-southeast-2"
```

---

## 📊 What the Script Does

| Step | Action | Time |
|------|--------|------|
| 1 | Create SSH key pair | ~5 sec |
| 2 | Create security group | ~10 sec |
| 3 | Detect your IP address | ~2 sec |
| 4 | Add firewall rules | ~30 sec |
| 5 | Find latest AMI | ~10 sec |
| 6 | Launch EC2 instance | ~10 sec |
| 7 | Wait for instance startup | ~30-60 sec |
| 8 | Get instance IP address | ~5 sec |
| 9 | Save configuration file | ~1 sec |
| 10 | Tag instance | ~5 sec |
| **TOTAL** | | **~2 minutes** |

---

## 📂 Files Created/Updated

After running the script:

```
d:\AI Work\ai-chatbot-devops\
├── scripts\
│   ├── launch-jenkins-ec2.ps1      (the script)
│   ├── jenkins-setup-ec2.sh        (setup script to run on EC2)
│   └── jenkins-iam-policy.json     (IAM permissions)
├── keys\
│   └── jenkins-key.pem             (SSH private key - KEEP SAFE!)
└── jenkins-ec2-config.txt          (instance details for reference)
```

---

## 🔐 Security Group Rules Added

The script automatically creates these firewall rules:

```
Inbound:
- SSH (22)      → Your IP only
- Jenkins (8080) → Your IP only  
- Agents (50000) → Your IP only

Outbound:
- All traffic allowed
```

This ensures only YOUR computer can access Jenkins!

---

## ✅ Expected Output

When successful, you'll see:

```
================================
🚀 Launching Jenkins EC2 Instance
================================

✅ Checking AWS CLI...
Found: aws-cli/2.x.x

📍 Using Region: ap-southeast-2

STEP 1: Creating Key Pair...
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Key pair created at: d:\AI...\keys\jenkins-key.pem

STEP 2: Creating Security Group...
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Security group 'jenkins-security-group' already exists

[... more steps ...]

================================
✅ EC2 Instance Created Successfully!
================================

🏷️  Instance Name: jenkins-controller
🆔 Instance ID: i-0abc12345def67890
📍 Public IP: 54.123.456.789
📍 Private IP: 172.31.0.123
🔑 Key Name: jenkins-key
🛡️  Security Group: jenkins-security-group (sg-0abc12345def)

📋 NEXT STEPS:

1️⃣  SSH into your instance (wait 2-3 minutes first):
   ssh -i "keys\jenkins-key.pem" ec2-user@54.123.456.789

[...]
```

---

## 🔧 Troubleshooting

### **Error: AWS CLI not found**
```powershell
# Install AWS CLI v2 from:
https://aws.amazon.com/cli/
```

### **Error: AWS credentials not configured**
```powershell
# Run:
aws configure

# Enter:
AWS Access Key ID: [your ID]
AWS Secret Access Key: [your key]
Default region: ap-southeast-2
Default output format: json
```

### **Error: Permission denied (key pair)**
```powershell
# Fix permissions on the .pem file:
icacls "keys\jenkins-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(F)"
```

### **Error: Security group already exists (with different rules)**
```powershell
# Manually add SSH rule:
aws ec2 authorize-security-group-ingress `
    --group-name jenkins-security-group `
    --protocol tcp `
    --port 22 `
    --cidr YOUR_IP/32 `
    --region ap-southeast-2
```

### **Can't connect via SSH**
- Wait 2-3 minutes for instance to fully initialize
- Check security group allows your IP on port 22
- Check .pem file path is correct
- Try: `ssh -v -i "keys\jenkins-key.pem" ec2-user@IP`

---

## 📝 Configuration File

After the script runs, check `jenkins-ec2-config.txt`:

```
Instance Details:
- Instance ID: i-0abc12345def67890
- Public IP: 54.123.456.789
- Private IP: 172.31.0.123

SSH Command:
ssh -i "keys\jenkins-key.pem" ec2-user@54.123.456.789

Jenkins URL:
http://54.123.456.789:8080
```

---

## 🎯 After EC2 Launch

Once the script completes:

1. **Wait 2-3 minutes** for instance to fully start
2. **SSH into it:**
   ```powershell
   ssh -i "keys\jenkins-key.pem" ec2-user@YOUR_IP
   ```
3. **Run setup script** (from EC2_JENKINS_SETUP_STEPS.md Step 4)
4. **Access Jenkins** at `http://YOUR_IP:8080`

---

## 💾 Saving Your Details

**Keep these safe:**
```
✅ Instance ID (for future reference)
✅ Public IP (for accessing Jenkins)
✅ Key file path (for SSH access)
✅ Security group name (if you need to modify rules)
```

All saved in: `jenkins-ec2-config.txt`

---

## ⚡ Quick Commands

```powershell
# Check instance status
aws ec2 describe-instances --instance-ids i-xxx --region ap-southeast-2

# Stop instance (to save money)
aws ec2 stop-instances --instance-ids i-xxx --region ap-southeast-2

# Terminate instance (delete it)
aws ec2 terminate-instances --instance-ids i-xxx --region ap-southeast-2

# Get current instance IP
aws ec2 describe-instances --instance-ids i-xxx --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region ap-southeast-2
```

---

Ready? Run: `.\scripts\launch-jenkins-ec2.ps1` 🚀
