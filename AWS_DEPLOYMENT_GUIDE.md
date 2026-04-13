# AWS Deployment Guide

This guide provides step-by-step instructions for deploying the AI Chatbot application to AWS using Terraform and EKS.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** (v1.0+)
4. **kubectl** for Kubernetes management
5. **Docker** for building and pushing images to ECR

## Architecture Overview

```
┌─────────────────────────────────────────┐
│            AWS Region                    │
├─────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                      │
│  ├─ Public Subnets (2x)                 │
│  │  ├─ NAT Gateways                     │
│  │  └─ Internet Gateway                 │
│  │                                       │
│  └─ Private Subnets (2x)                │
│     ├─ EKS Cluster                      │
│     │  ├─ Backend Deployment            │
│     │  ├─ Frontend Deployment           │
│     │  └─ Ingress Controller            │
│     │                                    │
│     └─ RDS PostgreSQL                   │
│                                          │
│  ECR Repositories                        │
│  ├─ Backend Image                       │
│  └─ Frontend Image                      │
└─────────────────────────────────────────┘
```

## Step 1: Prepare AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

## Step 2: Initialize Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan the infrastructure
terraform plan -out=tfplan
```

## Step 3: Deploy Infrastructure

```bash
# Review the plan
terraform show tfplan

# Apply the Terraform configuration
terraform apply tfplan

# Save outputs for reference
terraform output > outputs.json
```

## Step 4: Configure kubectl

```bash
# Get the configure kubectl command from Terraform output
aws eks update-kubeconfig --region us-east-1 --name ai-chatbot-cluster

# Verify cluster connection
kubectl cluster-info
kubectl get nodes
```

## Step 5: Build and Push Docker Images

### Option A: Using Docker Locally

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com

# Build backend image
cd backend
docker build -t [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com/ai-chatbot/backend:latest .
docker push [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com/ai-chatbot/backend:latest
cd ..

# Build frontend image
cd frontend
docker build -f Dockerfile -t [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com/ai-chatbot/frontend:latest .
docker push [ACCOUNT_ID].dkr.ecr.us-east-1.amazonaws.com/ai-chatbot/frontend:latest
cd ..
```

### Option B: Using GitHub Actions

- Push code to repository
- GitHub Actions workflow builds and pushes images automatically

## Step 6: Create Kubernetes Namespace and Secrets

```bash
# Create namespace
kubectl create namespace chatbot

# Create secrets for RDS connection
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id ai-chatbot/rds/password --query SecretString --output text)

kubectl create secret generic db-credentials \
  --from-literal=connection-string="postgresql://admin:PASSWORD@ENDPOINT:5432/chatbot_db" \
  -n chatbot

# Create OpenAI API key secret
kubectl create secret generic openai-credentials \
  --from-literal=api-key="YOUR_OPENAI_API_KEY" \
  -n chatbot
```

## Step 7: Deploy Application to Kubernetes

```bash
# Update image URLs in k8s manifests
# Edit k8s/backend-deployment.yaml and k8s/frontend-deployment.yaml

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/postgres-deployment.yaml  # Optional: if using k8s-hosted DB

# Verify deployments
kubectl get deployments -n chatbot
kubectl get pods -n chatbot
kubectl get services -n chatbot
```

## Step 8: Set Up Ingress Controller

```bash
# Install Ingress Nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Create Ingress resource
kubectl apply -f k8s/ingress.yaml

# Get Ingress endpoint
kubectl get ingress -n chatbot
```

## Step 9: Configure DNS

```bash
# Get the Ingress Load Balancer endpoint
kubectl get ingress -n chatbot -o wide

# Create DNS record pointing to the load balancer
# (Use Route53, your domain registrar, or any DNS service)
```

## Step 10: Monitor and Troubleshoot

```bash
# View pod logs
kubectl logs -f deployment/chatbot-backend -n chatbot

# Describe pod for events
kubectl describe pod <pod-name> -n chatbot

# Access pod shell
kubectl exec -it <pod-name> -n chatbot -- /bin/bash

# Check cluster events
kubectl get events -n chatbot

# Monitor resource usage
kubectl top nodes
kubectl top pods -n chatbot
```

## Scaling the Application

```bash
# Scale backend deployment
kubectl scale deployment chatbot-backend --replicas=3 -n chatbot

# Set up auto-scaling
kubectl autoscale deployment chatbot-backend \
  --min=2 --max=10 --cpu-percent=80 -n chatbot

# Check HPA status
kubectl get hpa -n chatbot
```

## Backup and Disaster Recovery

```bash
# Backup RDS database
aws rds create-db-snapshot \
  --db-instance-identifier ai-chatbot-db \
  --db-snapshot-identifier ai-chatbot-db-backup-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots --region us-east-1

# Backup Kubernetes resources
kubectl get all -n chatbot -o yaml > k8s-backup.yaml
```

## Cleanup and Destruction

```bash
# Delete Kubernetes resources
kubectl delete namespace chatbot

# Destroy Terraform infrastructure
cd terraform
terraform destroy

# Confirm deletion
terraform state list  # Should be empty
```

## Cost Optimization Tips

1. **Use Spot Instances** for worker nodes (non-critical workloads)
2. **Enable Auto-Scaling** to match demand
3. **Use RDS Reserved Instances** for predictable database usage
4. **Enable CloudWatch Alarms** for cost monitoring
5. **Use ECR Lifecycle Policies** to clean up old images
6. **Implement Pod Resource Limits** to prevent resource hogging

## Troubleshooting Common Issues

### Connection Refused to RDS
- Verify security groups allow port 5432 from EKS nodes
- Check RDS instance is multi-AZ and in correct subnets
- Verify database credentials in Kubernetes secrets

### Pods Not Starting
- Check pod status: `kubectl describe pod <pod-name> -n chatbot`
- Check logs: `kubectl logs <pod-name> -n chatbot`
- Verify image exists in ECR

### Ingress Not Working
- Verify Ingress controller is installed and running
- Check Ingress resource: `kubectl describe ingress -n chatbot`
- Verify backend services are accessible

### High Costs
- Monitor CloudWatch - check for unexpected resource usage
- Use AWS Billing Dashboard to identify cost drivers
- Review auto-scaling policies and adjust min/max replicas

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
