# Jenkins Pipeline Fix - AWS Credentials Configuration

## ❌ What Failed

The Jenkins pipeline failed with error: **`docker-credentials`**

**Root Cause:** AWS credentials are not configured in Jenkins

The Jenkinsfile tries to:
1. Get ECR login credentials from AWS
2. Push Docker images to ECR
3. Deploy to EKS using AWS CLI

But Jenkins doesn't have AWS credentials configured, so it fails.

---

## ✅ How To Fix - Add AWS Credentials to Jenkins

### Step 1: Get Your AWS Credentials

You need:
- **AWS Access Key ID**
- **AWS Secret Access Key**

**To get these:**
1. Go to: https://console.aws.amazon.com/iam/
2. Click **"Users"** in left menu
3. Click your username (or create a new user)
4. Click **"Security credentials"** tab
5. Under **"Access keys"** section, click **"Create access key"**
6. Copy both values immediately (secrets can't be viewed again):
   - **Access Key ID** (starts with `AKIA...`)
   - **Secret Access Key** (long random string)

---

### Step 2: Add Credentials to Jenkins

**In Jenkins Dashboard:**

1. Click **"Manage Jenkins"** (in left menu)
2. Click **"Manage Credentials"**
3. Under **"Stores scoped to Jenkins"** section, click **"Jenkins"**
4. In left menu, click **"Global credentials"** (not domain credentials)
5. Click **"Add Credentials"** (top right button)

**In the Add Credentials form:**

```
Kind:                    AWS Credentials (select from dropdown)
Scope:                   Global (default)
ID:                      aws-credentials        (EXACT - must match Jenkinsfile)
Description:             AWS Credentials for ECR and EKS
Access Key ID:           AKIA... (paste your access key)
Secret Access Key:       ... (paste your secret)
```

**Important:** The ID MUST be exactly `aws-credentials` (case-sensitive)

Click **"Create"**

---

### Step 3: Verify Credentials Added

Back on Credentials page, you should see:
```
aws-credentials
  AWS Credentials
  (Global)
```

---

## 🚀 Re-Run the Pipeline

Once credentials are added:

1. Go to Jenkins dashboard
2. Click your job: **"ai-chatbot-pipeline"**
3. Click **"Build Now"** (left menu)
4. Monitor the build in **"Console Output"**

**Expected output (new):**
```
[*] Verifying Docker availability...
[OK] Docker is available
[*] Verifying AWS CLI...
[OK] AWS CLI is available
[*] Building backend image...
[OK] Backend image built successfully
[*] Building frontend image...
[OK] Frontend image built successfully
[*] Authenticating with ECR...
[OK] Backend image pushed
[OK] Frontend image pushed
[*] Deploying to EKS cluster...
[OK] All deployments are healthy!
[OK] Pipeline executed successfully!
```

---

## 🔍 Troubleshooting

### If it still fails with "AWS credentials not found"

1. **Verify credential ID matches:**
   - In Jenkinsfile: `withAWS(credentials: 'aws-credentials'`
   - In Jenkins: Should be listed as `aws-credentials`

2. **Verify credential values:**
   - Access Key ID should start with `AKIA`
   - Secret Access Key should be a long random string
   - Both should be from same AWS user

3. **Verify AWS user has permissions:**
   - Should have ECR permissions (push images)
   - Should have EKS permissions (update kubeconfig)
   - Should have EC2 permissions (describe instances)

### If it fails with "Docker daemon not accessible"

Run this on EC2 to verify:
```bash
ssh -i "path/to/jenkins-key.pem" ec2-user@3.26.175.20
sudo docker ps
```

If Docker isn't running:
```bash
sudo systemctl start docker
```

### If it fails with "kubectl not found"

Run this on EC2:
```bash
ssh ec2-user@3.26.175.20
kubectl version --client
```

If not found, install:
```bash
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.24.7/2022-10-31/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

---

## 📝 Updated Jenkinsfile Features

The updated Jenkinsfile now includes:

✅ **Proper credential binding** with `withAWS()`  
✅ **Prerequisites verification** (Docker, AWS CLI)  
✅ **Better error messages** with troubleshooting hints  
✅ **Improved error handling** with set +e/set -e  
✅ **Detailed logging** at each stage  
✅ **Failure post-actions** with common issues  

---

## ✅ Summary

1. **Get AWS credentials** (Access Key ID + Secret)
2. **Add to Jenkins** (ID: `aws-credentials`)
3. **Rebuild pipeline** (Build Now)
4. **Monitor console** for success

---

## 🎯 Next Steps

1. Go to AWS IAM console and copy your Access Key + Secret
2. In Jenkins: Manage Jenkins → Manage Credentials → Add Credentials
3. Fill in the form with your AWS credentials (ID: `aws-credentials`)
4. Click "Create"
5. Go to your job and click "Build Now"
6. Watch the console output - should build and push successfully!

---

**Status: Ready after credentials are added** ✅
