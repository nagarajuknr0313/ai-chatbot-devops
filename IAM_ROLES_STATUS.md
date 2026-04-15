# AWS EKS Deployment - Using Existing IAM Roles

## IAM Roles Status

### Cluster Role ✅
- **Name:** AmazonEKSAutoClusterRole
- **Purpose:** EKS Cluster control plane
- **Status:** Created by user

### Node Group Role ❓
- **Name:** ai-chatbot-eks-node-group-role
- **Purpose:** EC2 worker nodes
- **Status:** Still needs to be created

---

## Quick Setup Steps

### Option 1: Let Me Create the Node Role (Automated)

```bash
# Create Node Group IAM role via PowerShell
$NodeTrust = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

$NodeTrust | Out-File -FilePath node-trust.json -Encoding UTF8

aws iam create-role --role-name ai-chatbot-eks-node-group-role `
    --assume-role-policy-document file://node-trust.json

aws iam attach-role-policy --role-name ai-chatbot-eks-node-group-role `
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy --role-name ai-chatbot-eks-node-group-role `
    --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy --role-name ai-chatbot-eks-node-group-role `
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

rm node-trust.json
```

### Option 2: You Create Both Roles in AWS Console

1. Create second role: `ai-chatbot-eks-node-group-role`
   - Trust: EC2 Service
   - Policies:
     - AmazonEKSWorkerNodePolicy
     - AmazonEKS_CNI_Policy
     - AmazonEC2ContainerRegistryReadOnly

---

## Next: Deploy EKS Cluster & Nodes

Once roles are ready:

```bash
# Get the ARN of your cluster role
$CLUSTER_ROLE = aws iam get-role --role-name AmazonEKSAutoClusterRole --query Role.Arn --output text

# Deploy EKS infrastructure
cd d:\AI Work\ai-chatbot-devops
.\deploy-eks-with-roles.ps1 -ClusterRoleArn $CLUSTER_ROLE
```

---

## What I Need From You:

1. **Confirm:** Is `AmazonEKSAutoClusterRole` meant for the EKS Cluster control plane?
2. **Choose One:**
   - A) I'll create the Node Group role automatically (run PowerShell above)
   - B) You'll create the Node Group role in AWS Console
3. **Then:** I'll run the deployment with both roles

What would you prefer?
