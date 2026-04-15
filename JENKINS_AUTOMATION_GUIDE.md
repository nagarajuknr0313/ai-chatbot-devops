# Jenkins CI/CD Automation Strategy - Complete Guide

## 🎯 Architecture Decision: Local vs EC2

### **RECOMMENDATION: EC2 Agent (Best for Production)**

| Aspect | Local Jenkins | EC2 Jenkins Agent |
|--------|---------------|-------------------|
| **Availability** | Only when dev machine running ❌ | 24/7 availability ✅ |
| **Scalability** | Single machine limit ❌ | Scale with multiple agents ✅ |
| **Production Ready** | ❌ Not recommended | ✅ Recommended |
| **CI/CD Triggers** | Manual/polling only | Webhook triggers from GitHub ✅ |
| **Cost** | Free (dev only) | ~$5-10/month for t3.small instance |
| **Auto-Deployment** | No | Yes ✅ |
| **Team Access** | No | Yes ✅ |

### **Hybrid Approach (BEST FOR YOU RIGHT NOW):**
1. **Keep Local Jenkins** for testing and development
2. **Add EC2 Agent** for production automated deployments
3. **GitHub Webhooks** trigger automated builds on code push

---

## 📋 Complete Automation Pipeline

### **Workflow Overview**
```
Developer pushes code 
    ↓
GitHub Webhook triggers Jenkins
    ↓
Jenkins Job runs on EC2 Agent
    ├─ Build backend Docker image
    ├─ Build frontend Docker image
    ├─ Push to AWS ECR
    ├─ Deploy to EKS cluster
    └─ Notify slack/email on success/failure
```

---

## 🔧 Step 1: Setup EC2 Jenkins Agent

### **1.1 Launch EC2 Instance for Jenkins Controller**

```powershell
# Use AWS CLI to launch (or do manually in AWS Console)
$InstanceType = "t3.medium"  # Recommended for Jenkins controller
$KeyPair = "your-key-pair"   # Create in AWS Console first
```

### **1.2 EC2 Instance Requirements**

**Minimum Specs:**
- **Instance Type:** t3.medium or t3.large (for production)
- **OS:** Amazon Linux 2 or Ubuntu 22.04 LTS
- **Storage:** 20GB root volume (builds will use 50GB+)
- **Security Group Rules:**
  - Port 8080 (Jenkins UI) - from your IP only
  - Port 50000 (Agent communication) - from agent security group
  - SSH 22 - from your IP only

**IAM Role Permissions Needed:**
- ECR (push/pull images)
- EKS (kubectl access)
- EC2 (create/manage resources)

### **1.3 Setup Jenkins on EC2**

```bash
#!/bin/bash
# SSH into EC2 instance and run:

# Update system
sudo yum update -y

# Install Java 11 (required for Jenkins)
sudo yum install -y java-11-amazon-corretto

# Install Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo usermod -a -G docker jenkins

# Install kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## 🚀 Step 2: Update Jenkinsfile for EKS Automation

### **2.1 Create Advanced Jenkinsfile (Updated)**

Here's the updated Jenkinsfile with ECR and EKS integration:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '868987408656'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        BACKEND_IMAGE = "${ECR_REGISTRY}/chatbot-backend"
        FRONTEND_IMAGE = "${ECR_REGISTRY}/chatbot-frontend"
        K8S_NAMESPACE = 'chatbot'
        EKS_CLUSTER_NAME = 'ai-chatbot-cluster'
        BUILD_TAG = "${BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    stages {
        stage('🔍 Checkout') {
            steps {
                checkout scm
                script {
                    echo "✅ Checking out branch: ${env.GIT_BRANCH}"
                    echo "✅ Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('🐳 Build Backend Image') {
            steps {
                script {
                    echo "🔨 Building backend image: ${BACKEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${BACKEND_IMAGE}:${BUILD_TAG} \
                            -t ${BACKEND_IMAGE}:latest \
                            -f backend/Dockerfile \
                            backend/
                    '''
                }
            }
        }

        stage('🎨 Build Frontend Image') {
            steps {
                script {
                    echo "🔨 Building frontend image: ${FRONTEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${FRONTEND_IMAGE}:${BUILD_TAG} \
                            -t ${FRONTEND_IMAGE}:latest \
                            -f frontend/Dockerfile \
                            frontend/
                    '''
                }
            }
        }

        stage('📦 Push to ECR') {
            steps {
                script {
                    echo "🚀 Pushing images to ECR..."
                    sh '''
                        # Login to ECR
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        # Push backend
                        echo "Pushing backend: ${BACKEND_IMAGE}:${BUILD_TAG}"
                        docker push ${BACKEND_IMAGE}:${BUILD_TAG}
                        docker push ${BACKEND_IMAGE}:latest

                        # Push frontend
                        echo "Pushing frontend: ${FRONTEND_IMAGE}:${BUILD_TAG}"
                        docker push ${FRONTEND_IMAGE}:${BUILD_TAG}
                        docker push ${FRONTEND_IMAGE}:latest
                    '''
                }
            }
        }

        stage('☸️ Deploy to EKS') {
            steps {
                script {
                    echo "📋 Deploying to EKS cluster: ${EKS_CLUSTER_NAME}"
                    sh '''
                        # Configure kubectl
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER_NAME}

                        # Restart deployments to pull new images
                        echo "🔄 Restarting backend deployment..."
                        kubectl rollout restart deployment/backend -n ${K8S_NAMESPACE}
                        kubectl rollout status deployment/backend -n ${K8S_NAMESPACE} --timeout=5m

                        echo "🔄 Restarting frontend deployment..."
                        kubectl rollout restart deployment/frontend -n ${K8S_NAMESPACE}
                        kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE} --timeout=5m

                        # Get deployment info
                        echo "📊 Deployment Status:"
                        kubectl get deployments -n ${K8S_NAMESPACE}
                        kubectl get pods -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        stage('✅ Verify Deployment') {
            steps {
                script {
                    echo "🔍 Verifying deployment health..."
                    sh '''
                        # Check if all pods are running
                        BACKEND_READY=$(kubectl get deployment backend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
                        FRONTEND_READY=$(kubectl get deployment frontend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

                        if [[ "$BACKEND_READY" == "True" && "$FRONTEND_READY" == "True" ]]; then
                            echo "✅ All deployments are healthy!"
                            exit 0
                        else
                            echo "❌ Deployment health check failed!"
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
            // Add Slack notification here
            // sh 'curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\"✅ Deployment to EKS successful\\"}" $SLACK_WEBHOOK'
        }
        failure {
            echo '❌ Pipeline failed!'
            // Add Slack notification here
        }
        always {
            // Cleanup
            sh 'docker logout ${ECR_REGISTRY} || true'
        }
    }
}
```

---

## 🔐 Step 3: Configure Jenkins Credentials

### **3.1 Add AWS Credentials to Jenkins**

1. Go to Jenkins → **Manage Jenkins** → **Manage Credentials**
2. Click **Add Credentials**
3. Choose **AWS Credentials**
4. Fill in:
   - Access Key ID: `Your AWS Access Key`
   - Secret Access Key: `Your AWS Secret Key`
   - ID: `aws-credentials`

### **3.2 Create Jenkins Pipeline Job**

1. **Jenkins** → **New Item**
2. Enter job name: `chatbot-deployment-pipeline`
3. Select **Pipeline**
4. Under **Pipeline** section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/your-repo/ai-chatbot-devops.git`
   - Credentials: GitHub token (if private repo)
   - Script Path: `Jenkinsfile`

### **3.3 Configure GitHub Webhook (Auto-trigger)**

#### **In GitHub Repository:**
1. Go to **Settings** → **Webhooks**
2. Click **Add webhook**
3. Fill in:
   - **Payload URL:** `http://your-ec2-ip:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Push events
   - **Active:** ✅ Checked

---

## 📊 Step 4: Jenkins Configuration

### **4.1 Jenkins System Configuration**

1. **Manage Jenkins** → **Configure System**
2. Under **GitHub** section:
   - Check **Manage hooks**
   - Add GitHub token (Personal Access Token)

### **4.2 Install Required Jenkins Plugins**

```groovy
// Go to: Manage Jenkins → Manage Plugins → Available
// Install these:
- Pipeline
- Docker Pipeline
- AWS SDK
- EKS / Kubernetes
- GitHub Integration
- Blue Ocean (Nice UI - Optional)
```

---

## 🎯 Step 5: Testing the Pipeline

### **Test 1: Manual Trigger**
```bash
1. Go to Jenkins Job
2. Click "Build Now"
3. Check console output
```

### **Test 2: GitHub Push Trigger**
```bash
# Make a change and push to GitHub
git add .
git commit -m "Test Jenkins auto-deploy"
git push origin main

# Jenkins should automatically trigger build!
```

---

## 🛠️ Troubleshooting

### **Common Issues**

**Issue 1: ECR Login Fails**
```bash
# Solution: Check AWS credentials in Jenkins
# Try: aws ecr get-login-password --region ap-southeast-2
```

**Issue 2: kubectl not found**
```bash
# Solution: Install kubectl on Jenkins instance
curl -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl
```

**Issue 3: Cannot pull Docker image from ECR**
```bash
# Solution: Check EKS node IAM role has ECR permissions
```

---

## 📈 Production Setup Recommendations

### **High Availability Setup:**
1. **Jenkins Controller** on EC2 t3.large
2. **Jenkins Agents** (2-3 x t3.medium) - for parallel builds
3. **RDS for Jenkins database** (backup jobs)
4. **S3 for build artifacts** backup
5. **CloudWatch** for monitoring

### **Security Best Practices:**
- ✅ Use IAM roles instead of access keys
- ✅ Store credentials in AWS Secrets Manager
- ✅ Enable HTTPS on Jenkins (use ALB)
- ✅ Restrict security group access
- ✅ Enable Jenkins audit logging
- ✅ Implement RBAC in Jenkins

---

## 💡 Quick Decision Matrix

| Your Scenario | Recommendation |
|:---|:---|
| Dev/Testing only | Keep Local Jenkins |
| Small team + production | EC2 Jenkins (t3.medium) |
| Large team + critical | Jenkins on ECS/EKS + RDS |
| Maximum automation | Jenkins + GitHub Actions (hybrid) |

---

## 🚀 Next Steps

1. **Launch EC2 instance** for Jenkins Controller
2. **Setup Jenkins** using provided bash script
3. **Configure AWS credentials** in Jenkins
4. **Update Jenkinsfile** with provided pipeline
5. **Setup GitHub webhook** for auto-triggering
6. **Test** with manual push to GitHub

---

**Your Complete Automation Flow:**
```
Developer Code Push 
  → GitHub Webhook 
    → Jenkins Build Triggered 
      → Build Docker Images 
        → Push to ECR 
          → Update EKS Deployments 
            → Auto-Restart Pods 
              → Slack Notification ✓
```
