# AWS EKS Deployment Status & Path Forward
# April 15, 2026

## Current Status

✅ **What's Been Done:**  
- Created VPC: `vpc-0b01101882c5a3e0a` (10.0.0.0/16) in ap-southeast-2
- Created deployment automation scripts
- Created comprehensive guides
- Verified AWS credentials for account: 868987408656

❌ **What Needs Attention:**
- AWS CLI is experiencing timeout issues on some operations
- Previous EKS cluster reference found in kubeconfig (appears to be from prior deployment)
- Need to perform remaining infrastructure setup

---

## Recommended Path Forward (Option A - Automated)

Use AWS CloudFormation instead of manual AWS CLI (faster & more reliable):

```bash
# 1. Download official EKS CloudFormation template
aws s3 cp s3://aws-quickstart/quickstart-amazon-eks-cluster/ . --recursive --region ap-southeast-2

# 2. Create stack (takes 20-30 minutes)
aws cloudformation create-stack `
  --stack-name ai-chatbot-eks-stack `
  --template-body file://templates/aws-eks-cluster.yaml `
  --capabilities CAPABILITY_NAMED_IAM `
  --region ap-southeast-2
```

---

## Recommended Path Forward (Option B - Manual AWS Console)

Use AWS Console for remaining infrastructure setup (most reliable):

### **Step 1: Delete Previous kubeconfig**
```bash
# Remove old cluster reference
aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2 --kubeconfig ~/.kube/config-delete

# Or manually edit: %USERPROFILE%\.kube\config
# Remove the cluster section with hostname: 0D93D99A178EB4B5EAE...
```

### **Step 2: Create IAM Roles** (AWS Console)
1. Go to: https://console.aws.amazon.com/iam/
2. Create Role: `ai-chatbot-eks-cluster-role`
   - Trust: EKS Service
   - Attach: `AmazonEKSClusterPolicy`
3. Create Role: `ai-chatbot-eks-node-group-role`
   - Trust: EC2 Service
   - Attach: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`

### **Step 3: Create EKS Cluster** (AWS Console)
1. Go to: https://console.aws.amazon.com/eks/
2. Click "Create cluster"
3. Configuration:
   - Name: `ai-chatbot-cluster`
   - Version: 1.28
   - Cluster Service Role: `ai-chatbot-eks-cluster-role`
   - VPC: `vpc-0b01101882c5a3e0a`
   - Subnets: Select public & private subnets (we created: 10.0.1.0/24, 10.0.2.0/24, 10.0.10.0/24, 10.0.11.0/24)
4. Click "Create" (takes 5-10 minutes)

### **Step 4: Create Node Group** (AWS Console)
1. In EKS cluster detail, go to "Compute" tab
2. Add node group:
   - Name: `ai-chatbot-node-group`
   - Node Role: `ai-chatbot-eks-node-group-role`
   - Subnets: Private subnets (10.0.10.0/24, 10.0.11.0/24)
   - Instance Type: t3.medium
   - Desired Size: 2
   - Min: 2, Max: 5
3. Click "Create" (takes 5-15 minutes)

### **Step 5: Configure kubectl**
```bash
aws eks update-kubeconfig --region ap-southeast-2 --name ai-chatbot-cluster
kubectl cluster-info
```

### **Step 6: Create ECR Repositories**
```bash
aws ecr create-repository --repository-name "ai-chatbot/backend" --region ap-southeast-2
aws ecr create-repository --repository-name "ai-chatbot/frontend" --region ap-southeast-2
```

### **Step 7: Build & Push Images**
```bash
# Backend
cd backend
docker build -t 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/backend:latest .
docker push 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/backend:latest
cd ..

# Frontend
cd frontend
docker build -t 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/frontend:latest .
docker push 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/frontend:latest
cd ..
```

### **Step 8: Deploy to Kubernetes**
```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Create secrets
kubectl create secret generic database-secret `
  --from-literal=password=YourSecurePassword123 `
  --from-literal=username=chatbot `
  --from-literal=dbname=chatbot_db `
  -n chatbot

# Deploy applications
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml

# Verify
kubectl get pods -n chatbot
```

---

## Available Scripts

| Script | Purpose | Status |
|--------|---------|--------|
| `deploy-eks-simple.ps1` | Simple EKS infrastructure deployment | Ready but encountering AWS CLI timeouts |
| `build-and-push-images.ps1` | Build and push Docker images to ECR | Ready to use |
| `deploy-to-kubernetes.ps1` | Deploy apps to K8s cluster | Ready to use |
| `AWS_DEPLOYMENT_QUICK_START.md` | Detailed step-by-step guide | Reference |
| `MANUAL_DEPLOYMENT_STEPS.md` | Command reference for manual steps | Reference |

---

## Quick Command Reference

```bash
# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ai-chatbot-vpc" --region ap-southeast-2

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0b01101882c5a3e0a" --region ap-southeast-2 --query "Subnets[*].[SubnetId,CidrBlock,Tags[?Key=='Name'].Value|[0]]"

# Check cluster (after creation)
aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 --query "cluster.status"

# Check nodes (after cluster ready)
kubectl get nodes -o wide

# Check node group
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 --query "nodegroup.status"
```

---

## Cost Estimates

| Resource | Hourly | Monthly |
|----------|--------|---------|
| EKS Cluster | $0.10 | $72 |
| 2x t3.medium | $0.067 | $48 |
| NAT Gateway | $0.045 | $33 |
| **TOTAL** | **$0.21** | **~$153** |

---

## My Recommendation

**Use Option B (AWS Console) for now** because:
- ✅ More reliable (no CLI timeout issues)
- ✅ Visual feedback as resources are created
- ✅ Can monitor progress in real-time
- ✅ Easier to troubleshoot
- ✅ Takes only 30-45 minutes total

Once cluster is created and nodes are ready, run:
```bash
.\build-and-push-images.ps1
.\deploy-to-kubernetes.ps1
```

---

## Next Steps

1. **Choose your approach**: AWS Console (Option B - recommended) or retry automation (Option A)
2. **If AWS Console**: Create EKS cluster and node group (~30 min)
3. **Once cluster ready**: Run build-and-push-images.ps1 (~10 min)
4. **Then deploy**: Run deploy-to-kubernetes.ps1 (~5 min)
5. **Access application**: Get LoadBalancer URL and access your app

---

**Status:** Ready to proceed with Option B (AWS Console) ✅
