# AWS Deployment Quick Start Guide
## AI Chatbot DevOps - ap-southeast-2 (Sydney)

**Total Time: ~30-40 minutes**

---

## 📋 Prerequisites

✅ **Already verified:**
- AWS CLI configured (Account: 868987408656)
- kubectl installed
- Docker installed

---

## 🚀 Step-by-Step Deployment

### **STEP 1: Deploy Infrastructure to AWS** (5-10 minutes)

```powershell
cd "d:\AI Work\ai-chatbot-devops"
.\deploy-to-aws.ps1
```

**What this does:**
- ✅ Creates VPC with public/private subnets
- ✅ Sets up NAT Gateways for private subnet internet access
- ✅ Creates EKS Cluster in ap-southeast-2
- ✅ Creates Node Group with 2 EC2 instances (t3.medium)
- ✅ Configures kubectl to access the cluster

**Monitoring:**
```powershell
# Check cluster status
aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 --query "cluster.status"

# Check nodes after cluster is ACTIVE (takes 5-10 minutes)
kubectl get nodes
```

---

### **STEP 2: Wait for Cluster to be Ready** (5-15 minutes)

The script will wait for the EKS cluster to reach ACTIVE state. This is normal and expected.

```powershell
# Monitor progress in another terminal
kubectl get nodes --watch

# You'll see something like:
# NAME                                     STATUS   ROLES    AGE     VERSION
# ip-10-0-10-1.ap-southeast-2.compute...   Ready    <none>   5m      v1.28.x
# ip-10-0-11-1.ap-southeast-2.compute...   Ready    <none>   4m      v1.28.x
```

---

### **STEP 3: Create ECR Repositories** (2 minutes)

```powershell
$ACCOUNT_ID = "868987408656"
$REGION = "ap-southeast-2"
$PROJECT = "ai-chatbot"

# Create backend repository
aws ecr create-repository `
  --repository-name "$PROJECT/backend" `
  --region $REGION

# Create frontend repository
aws ecr create-repository `
  --repository-name "$PROJECT/frontend" `
  --region $REGION

# Get login password
$LOGIN_PASSWORD = aws ecr get-login-password --region $REGION

# Log in to ECR
$LOGIN_PASSWORD | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
```

---

### **STEP 4: Build and Push Backend Image** (5 minutes)

```powershell
$ACCOUNT_ID = "868987408656"
$REGION = "ap-southeast-2"
$ECR_REPO = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

cd "backend"

# Build image
docker build -t "$ECR_REPO/ai-chatbot/backend:latest" .

# Push to ECR
docker push "$ECR_REPO/ai-chatbot/backend:latest"

Write-Host "✓ Backend image pushed successfully" -ForegroundColor Green

cd ".."
```

---

### **STEP 5: Build and Push Frontend Image** (5 minutes)

```powershell
$ACCOUNT_ID = "868987408656"
$REGION = "ap-southeast-2"
$ECR_REPO = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

cd "frontend"

# Build image
docker build -t "$ECR_REPO/ai-chatbot/frontend:latest" .

# Push to ECR
docker push "$ECR_REPO/ai-chatbot/frontend:latest"

Write-Host "✓ Frontend image pushed successfully" -ForegroundColor Green

cd ".."
```

---

### **STEP 6: Deploy to Kubernetes** (5 minutes)

Before deploying, update the Kubernetes manifests with your ECR image URIs:

```powershell
$ACCOUNT_ID = "868987408656"
$REGION = "ap-southeast-2"
$ECR_REPO = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Deploy namespace and config
kubectl apply -f k8s/namespace.yaml
Write-Host "✓ Namespace created" -ForegroundColor Green

# Deploy backend
kubectl apply -f k8s/backend-deployment.yaml
Write-Host "✓ Backend deployed" -ForegroundColor Green

# Deploy frontend
kubectl apply -f k8s/frontend-deployment.yaml
Write-Host "✓ Frontend deployed" -ForegroundColor Green

# Monitor deployment
kubectl get pods -n chatbot --watch
```

**Wait for pods to be ready:**
```
NAME                        READY   STATUS    RESTARTS   AGE
backend-xxxxxxxxxx-xxxxx    1/1     Running   0          2m
frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

---

### **STEP 7: Access Your Application** (1 minute)

```powershell
# Get service endpoints
kubectl get services -n chatbot

# Get LoadBalancer external IP
kubectl get svc -n chatbot -o wide

# Port-forward for local testing (optional)
kubectl port-forward -n chatbot svc/frontend-service 3000:80
kubectl port-forward -n chatbot svc/backend-service 8000:8000
```

---

## 🔍 Verification Commands

```powershell
# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check pods
kubectl get pods -n chatbot -o wide

# Check services
kubectl get svc -n chatbot

# Check ingress
kubectl get ingress -n chatbot

# View pod logs
kubectl logs -n chatbot -f deployment/backend
kubectl logs -n chatbot -f deployment/frontend

# Describe a pod
kubectl describe pod -n chatbot <pod-name>
```

---

## 🧹 Cleanup (if needed)

To remove everything from AWS:

```powershell
# Delete Kubernetes resources
kubectl delete namespace chatbot

# Delete ECR repositories
aws ecr delete-repository --repository-name "ai-chatbot/backend" --force --region ap-southeast-2
aws ecr delete-repository --repository-name "ai-chatbot/frontend" --force --region ap-southeast-2

# Delete EKS cluster (takes 10-15 minutes)
aws eks delete-cluster --name ai-chatbot-cluster --region ap-southeast-2

# Delete Node Group
aws eks delete-nodegroup --cluster-name ai-chatbot-cluster --nodegroup-name ai-chatbot-node-group --region ap-southeast-2

# Delete VPC and associated resources
aws ec2 delete-vpc --vpc-id <vpc-id> --region ap-southeast-2
```

---

## ⚠️ Cost Implications

**Estimated monthly costs (ap-southeast-2):**
- ✅ EKS Cluster: **$0.20 USD/hour** (~$144/month)
- ✅ EC2 Instances (2x t3.medium): **$0.033 USD/hour each** (~$48/month)
- ✅ NAT Gateway: **$0.045 USD/hour** (~$33/month)
- ✅ Data Transfer: Varies (usually <$10/month)

**Total Estimate: ~$225/month** (US pricing, Sydney may vary)

To save costs:
- Use spot instances instead of on-demand
- Scale down to 1 node when not in use
- Delete unused resources regularly

---

## 🆘 Troubleshooting

### **Nodes not appearing in kubectl**
```powershell
# Wait for node group to be ACTIVE
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 --query "nodegroup.status"

# Should show "ACTIVE"
```

### **Pods stuck in Pending**
```powershell
# Check events
kubectl describe node

# Check pod events
kubectl describe pod -n chatbot <pod-name>
```

### **ECR login fails**
```powershell
# Re-authenticate with ECR
$LOGIN_PASSWORD = aws ecr get-login-password --region ap-southeast-2
$LOGIN_PASSWORD | docker login --username AWS --password-stdin "868987408656.dkr.ecr.ap-southeast-2.amazonaws.com"
```

### **kubectl access denied**
```powershell
# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-2 --name ai-chatbot-cluster

# Verify access
kubectl cluster-info
```

---

## 📞 Support

For issues, check:
1. AWS CloudWatch Logs
2. EKS Events: `kubectl get events -n chatbot`
3. Pod Logs: `kubectl logs -n chatbot deployment/<service>`
4. AWS Console: https://console.aws.amazon.com

---

**Status: Ready to deploy! 🚀**

Start with Step 1 above.
