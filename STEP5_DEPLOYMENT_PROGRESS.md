# STEP 5 Deployment Progress - New AWS Account (ap-southeast-2)

**Status:** Infrastructure Setup in Progress | Date: 2026-04-14

---

## ✅ Completed Tasks

### 1. AWS Credentials & Identity Verified
- **Account ID:** 868987408656 (New AWS Account)
- **Region Configuration:** 
  - IAM/Console: us-east-1
  - EKS/ECR/Compute: ap-southeast-2
- **Verification:** `aws sts get-caller-identity` ✓

### 2. IAM Roles Created
- **Cluster Role:** ai-chatbot-eks-cluster-role
  - ARN: `arn:aws:iam::868987408656:role/ai-chatbot-eks-cluster-role`
  - Trust Policy: eks.amazonaws.com ✓
  - Attached Policy: AmazonEKSClusterPolicy ✓

- **Node Group Role:** ai-chatbot-eks-node-group-role
  - ARN: `arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role`
  - Trust Policy: ec2.amazonaws.com ✓
  - Attached Policies:
    - AmazonEKSWorkerNodePolicy ✓
    - AmazonEKS_CNI_Policy ✓
    - AmazonEC2ContainerRegistryReadOnly ✓

### 3. VPC Network Infrastructure Created (ap-southeast-2)
- **VPC:** vpc-0c66e9367af7a04e2
  - CIDR: 10.0.0.0/16

- **Public Subnets:**
  - Public 1: subnet-05eac7d814fe70a92 (10.0.1.0/24, ap-southeast-2a)
  - Public 2: subnet-01dae599497231b5e (10.0.2.0/24, ap-southeast-2b)
  - Public IP mapping: Enabled ✓

- **Private Subnets:**
  - Private 1: subnet-0ed90c7bafd163d6d (10.0.10.0/24, ap-southeast-2a)
  - Private 2: subnet-0df3df51e8322aa9e (10.0.11.0/24, ap-southeast-2b)

- **Internet Gateway:** igw-0457f2d83072192b7
  - Attached to VPC ✓

### 4. Security Groups Created
- **EKS Cluster SG:** sg-0c39ebce05930ba0f
  - Allows HTTPS (443) from cluster SG itself ✓

- **EKS Node SG:** sg-02fe282674343b933
  - Allows 1025-65535 (node-to-node) from node SG ✓
  - Allows HTTPS (443) from cluster SG ✓

### 5. Configuration Files Updated
- **.env.example:**
  - AWS_REGION_CONSOLE=us-east-1
  - AWS_REGION_IAM=us-east-1
  - AWS_REGION_EKS=ap-southeast-2
  - AWS_REGION_ECR=ap-southeast-2
  - ECR_REGISTRY=868987408656.dkr.ecr.ap-southeast-2.amazonaws.com
  - AWS_ACCOUNT_ID=868987408656 ✓

- **terraform/variables.tf:**
  - Updated with region variables for dual-region setup ✓

---

## ⏳ In Progress

### EKS Cluster Creation
- **Status:** Creating...
- **Cluster Name:** ai-chatbot-cluster
- **Kubernetes Version:** 1.28
- **Expected Duration:** 10-15 minutes
- **Monitor with:** `aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2`

---

## 📋 Remaining Tasks

### Phase 1: EKS Cluster & Nodes
- [ ] Wait for EKS Cluster to reach ACTIVE status (currently CREATING)
- [ ] Create Node Group (ai-chatbot-node-group)
  - Instance Type: t3.medium
  - Desired Capacity: 1
  - Min: 1, Max: 4

### Phase 2: Container Registry & Database
- [ ] Create ECR Repositories (ai-chatbot/backend, ai-chatbot/frontend)
- [ ] Create RDS PostgreSQL Database
  - Instance: db.t3.micro
  - Engine: PostgreSQL 14.22
  - Subnets: Private (multi-AZ)
  - Security Group: Allow 5432 from EKS nodes

### Phase 3: Deployment
- [ ] Configure kubectl for cluster
  - `aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2`
- [ ] Create Kubernetes namespace (chatbot)
- [ ] Create Kubernetes secrets for database credentials
- [ ] Deploy backend pods (replicas: 3)
- [ ] Deploy frontend pods (replicas: 2)
- [ ] Deploy postgres pod (replicas: 1)
- [ ] Create LoadBalancer services

### Phase 4: Verification
- [ ] Verify all 6 pods are Running
- [ ] Check frontend LoadBalancer IP assignment
- [ ] Test health checks:
  - Backend API: `GET /api/health`
  - Database connection from backend logs
  - Frontend accessibility via browser

---

## 🔧 Troubleshooting Notes

**Issue:** Service (AWS CLI/boto3) commands seemed to hang or not execute properly
**Resolution:** Using Python scripts with boto3 for more reliable EKS API interaction

**Current Environment:**
- Windows 11 PowerShell
- Python 3.14.4
- AWS CLI v2.34.30
- boto3 package (installing)

---

## 📊 Resource Summary

| Resource | Count | Region | Status |
|----------|-------|--------|--------|
| VPC | 1 | ap-southeast-2 | ✓ Created |
| Subnets | 4 | ap-southeast-2 | ✓ Created |
| Internet Gateway | 1 | ap-southeast-2 | ✓ Created |
| Security Groups | 2 | ap-southeast-2 | ✓ Created |
| IAM Roles | 2 | us-east-1 | ✓ Created |
| EKS Cluster | 1 | ap-southeast-2 | ⏳ Creating |
| Node Groups | 0 | ap-southeast-2 | ⌛ Pending |
| ECR Repositories | 0 | ap-southeast-2 | ⌛ Pending |
| RDS Instances | 0 | ap-southeast-2 | ⌛ Pending |

---

## ⏱️ Timeline

| Time | Event |
|------|-------|
| 11:42 | IAM roles created |
| 11:45 | VPC infrastructure created |
| 11:48 | Security groups created |
| 11:50 | Configuration files updated |
| 12:00 | EKS cluster creation initiated |
| 12:00+ | Awaiting cluster ACTIVE status |

---

## 🚀 Next Commands to Run

Once EKS Cluster is ACTIVE:

```bash
# 1. Create Node Group
aws eks create-nodegroup \
  --cluster-name ai-chatbot-cluster \
  --nodegroup-name ai-chatbot-node-group \
  --scaling-config minSize=1,maxSize=4,desiredSize=1 \
  --subnets subnet-0ed90c7bafd163d6d subnet-0df3df51e8322aa9e \
  --node-role arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role \
  --instance-types t3.medium \
  --region ap-southeast-2

# 2. Create ECR Repositories
aws ecr create-repository --repository-name ai-chatbot/backend --region ap-southeast-2
aws ecr create-repository --repository-name ai-chatbot/frontend --region ap-southeast-2

# 3. Configure kubectl
aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2

# 4. Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
```

---

## 📝 Notes

- All resources are tagged with `Project=AI-Chatbot`
- Cluster uses Kubernetes 1.28 (current stable)
- Node group uses t3.medium instances (can be scaled)
- RDS will use db.t3.micro (can be upgraded later)
- Local Docker Compose deployment remains as fallback

---

**Last Updated:** 2026-04-14 12:00 UTC+5:30
