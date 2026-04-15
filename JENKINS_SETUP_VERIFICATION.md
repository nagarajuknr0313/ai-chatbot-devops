# Jenkinsfile Verification & Jenkins Setup Checklist

## ✅ Jenkinsfile Values - Verified

### AWS Configuration
- ✅ AWS_REGION: `ap-southeast-2` (Correct)
- ✅ AWS_ACCOUNT_ID: `868987408656` (Correct - your AWS account)
- ✅ ECR_REGISTRY: `{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com` (Correct format)

### Application Images
- ✅ BACKEND_IMAGE: `chatbot-backend` (Exists in ECR)
- ✅ FRONTEND_IMAGE: `chatbot-frontend` (Exists in ECR)

### Kubernetes Configuration
- ✅ K8S_NAMESPACE: `chatbot` (Correct - where your apps are deployed)
- ✅ EKS_CLUSTER_NAME: `ai-chatbot-cluster` (Correct)

### Build Configuration
- ✅ BUILD_TAG: Uses build number + short commit hash (Good for traceability)
- ✅ Log retention: Keeps last 10 builds (Good)
- ✅ Timeout: 30 minutes (Reasonable)

---

## 🔧 Jenkins Configuration Steps

### Step 1: Access Jenkins Portal
**URL:** http://3.26.175.20:8080  
**Initial Admin Password:** `bed8f38db53948098d488c86dda6f410`

1. Open http://3.26.175.20:8080 in your browser
2. Enter the initial admin password
3. Click "Continue"
4. Click "Install suggested plugins" (takes 5-10 minutes)
5. Create your first admin user:
   - Username: `admin` (or your preference)
   - Password: (choose strong password)
   - Full Name: (optional)
   - Email: (optional)
6. Click "Save and Continue"
7. Confirm Jenkins URL: http://3.26.175.20:8080
8. Click "Save and Finish"

### Step 2: Add AWS Credentials to Jenkins

1. In Jenkins home → **Manage Jenkins** → **Manage Credentials**
2. Click **"Jenkins"** (under System)
3. Click **"Global credentials"** in left menu
4. Click **"Add Credentials"** button

**Fill in the following:**
- **Kind:** AWS Credentials
- **ID:** `aws-credentials` (exact name)
- **Description:** AWS Credentials for ECR and EKS
- **Access Key ID:** (from your AWS IAM user)
- **Secret Access Key:** (from your AWS IAM user)
- **Click "Create"**

### Step 3: Verify Docker is Available

Jenkins pipeline runs Docker commands. Verify it's available:

```bash
# SSH into Jenkins instance
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Check Docker
sudo docker --version

# Check if jenkins user can run docker (should be yes since we added to docker group)
sudo docker ps
```

### Step 4: Verify kubectl is Configured

Jenkins needs kubectl to deploy to EKS:

```bash
# SSH into Jenkins instance
ssh -i "d:\AI Work\ai-chatbot-devops\keys\jenkins-key-fixed.pem" ec2-user@3.26.175.20

# Check kubectl
kubectl version --client

# Check EKS cluster access
kubectl get nodes
```

If kubectl is not installed:
```bash
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.24.7/2022-10-31/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv kubectl /usr/local/bin/
```

### Step 5: Configure GitHub Webhook (Optional - For Auto Trigger)

**In GitHub Repository:**

1. Go to Settings → Webhooks → Add webhook
2. **Payload URL:** `http://3.26.175.20:8080/github-webhook/`
3. **Content type:** `application/json`
4. **Events to trigger:** 
   - ✅ Push events
   - ✅ Pull requests
5. Click **Add webhook**

---

## 🚀 Jenkinsfile Pipeline Stages

| Stage | What It Does | Requires |
|-------|-------------|----------|
| **Checkout** | Clones GitHub repo | Git access |
| **Build Backend** | Builds Docker image from `backend/Dockerfile` | Docker |
| **Build Frontend** | Builds Docker image from `frontend/Dockerfile` | Docker |
| **Push to ECR** | Pushes images to AWS ECR | AWS credentials, Docker login |
| **Deploy to EKS** | Restarts deployments to pull new images | AWS credentials, kubectl, EKS access |
| **Verify Deployment** | Checks if all pods are running | kubectl |

---

## 📋 Pre-Push Verification Checklist

Before pushing code to GitHub:

- [ ] Jenkins dashboard accessible at http://3.26.175.20:8080
- [ ] Jenkins initial setup wizard completed
- [ ] Admin user created and logged in
- [ ] AWS credentials added to Jenkins Credentials
- [ ] Docker is available (`docker --version` works)
- [ ] kubectl is available (`kubectl get nodes` works)
- [ ] EKS cluster accessible (`kubectl get nodes` shows EC2 nodes)
- [ ] ECR repositories exist (`aws ecr describe-repositories`)
- [ ] Jenkinsfile syntax is valid (no parsing errors)
- [ ] GitHub webhook configured (optional but recommended)

---

## 🔐 AWS Credentials Information

**You need to provide from your AWS account:**

1. **IAM User Access Key ID**
2. **IAM User Secret Access Key**

These credentials should have permissions for:
- ✅ ECR (push/pull images)
- ✅ EKS (update kubeconfig, access cluster)
- ✅ EC2 (describe instances)

**How to get AWS credentials:**

1. Go to AWS Console → IAM → Users
2. Select your user or create one for Jenkins
3. Click "Security credentials" tab
4. Create "Access key" if needed
5. Copy Access Key ID and Secret Access Key

---

## 🚀 Next Steps

1. **Complete Jenkins Setup:**
   - Access http://3.26.175.20:8080
   - Complete initial wizard
   - Add AWS credentials

2. **Verify Everything:**
   - SSH into instance and test Docker/kubectl
   - Verify AWS credentials in Jenkins

3. **Create Pipeline Job:**
   - New Item → Pipeline
   - Name: `ai-chatbot-deploy`
   - Pipeline → Definition: "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/YOUR_USERNAME/ai-chatbot-devops.git`
   - Credentials: GitHub (if private) or none (if public)
   - Script Path: `Jenkinsfile`

4. **Test Pipeline:**
   - Build Now (manual trigger)
   - Watch logs at http://3.26.175.20:8080/job/ai-chatbot-deploy/lastBuild/console

5. **Configure GitHub Webhook:**
   - Once pipeline works
   - Add webhook for auto-trigger

---

## 📝 Current System Status

**Jenkins Docker Instance:**
- IP: 3.26.175.20
- Port: 8080
- Status: Running (jenkins/jenkins:lts)
- Data: Persisted in ~/jenkins_home

**EKS Cluster:**
- Name: ai-chatbot-cluster
- Namespace: chatbot
- Region: ap-southeast-2
- Backend Pods: 3 replicas
- Frontend Pods: 2 replicas

**ECR Repositories:**
- chatbot-backend (pushed)
- chatbot-frontend (pushed)

---

**Ready to push code?** ✅ Yes, after stepping through above checklist!
