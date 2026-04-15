# AWS EKS Deployment - Manual Step-by-Step Guide
# Run each command individually and verify output

# ============================================================================
# STEP 1: Verify AWS Credentials
# ============================================================================
# Run this first to make sure you're authenticated

aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "868987408656",
#     "Account": "868987408656",
#     "Arn": "arn:aws:iam::868987408656:root"
# }

# ============================================================================
# STEP 2: Create ECR Repositories (for Docker images)
# ============================================================================

# Create backend repository
aws ecr create-repository `
  --repository-name "ai-chatbot/backend" `
  --region ap-southeast-2

# Create frontend repository
aws ecr create-repository `
  --repository-name "ai-chatbot/frontend" `
  --region ap-southeast-2

# Save the repository URIs - you'll need them later
$ACCOUNT_ID = "868987408656"
$BACKEND_REPO = "$ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/backend"
$FRONTEND_REPO = "$ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/frontend"

Write-Host "Backend Repo: $BACKEND_REPO"
Write-Host "Frontend Repo: $FRONTEND_REPO"

# ============================================================================
# STEP 3: Build and Push Backend Image
# ============================================================================

# Get ECR access token
$LOGIN = aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com"

# Build backend image
cd backend
docker build -t "$BACKEND_REPO:latest" .

# Push backend image to ECR
docker push "$BACKEND_REPO:latest"

# Resume from project root
cd ..

# ============================================================================
# STEP 4: Build and Push Frontend Image
# ============================================================================

# Build frontend image
cd frontend
docker build -t "$FRONTEND_REPO:latest" .

# Push frontend image to ECR
docker push "$FRONTEND_REPO:latest"

# Resume from project root
cd ..

# ============================================================================
# STEP 5: Configure kubectl for EKS Cluster
# ============================================================================
# NOTE: Only do this if your EKS cluster is already created and active

# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-2 --name ai-chatbot-cluster

# Verify connection
kubectl cluster-info

# Check nodes (if cluster and nodes are ready)
kubectl get nodes

# ============================================================================
# STEP 6: Create Kubernetes Namespace and ConfigMap
# ============================================================================

# Apply the namespace configuration
kubectl apply -f k8s/namespace.yaml

# Verify namespace was created
kubectl get namespace chatbot

# ============================================================================
# STEP 7: Create Kubernetes Secrets
# ============================================================================

# Create database credentials secret
kubectl create secret generic database-secret `
  --from-literal=password=mysecurepassword123 `
  --from-literal=username=chatbot `
  --from-literal=dbname=chatbot_db `
  -n chatbot

# Create API keys secret (replace with your actual OpenAI API key)
kubectl create secret generic api-keys `
  --from-literal=openai_api_key=sk-your-api-key-here `
  --from-literal=jwt_secret=$(New-Guid) `
  -n chatbot

# ============================================================================
# STEP 8: Deploy Applications to Kubernetes
# ============================================================================

# Update image references in YAML files
# Edit k8s/backend-deployment.yaml and change:
#   image: 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/backend:latest
#
# Edit k8s/frontend-deployment.yaml and change:
#   image: 868987408656.dkr.ecr.ap-southeast-2.amazonaws.com/ai-chatbot/frontend:latest

# Then deploy
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml

# ============================================================================
# STEP 9: Verify Deployment
# ============================================================================

# Check if pods are running
kubectl get pods -n chatbot

# Check services
kubectl get services -n chatbot

# Check ingress
kubectl get ingress -n chatbot

# View pod logs
kubectl logs -n chatbot deployment/backend -f

# ============================================================================
# STEP 10: Access Your Application
# ============================================================================

# Get LoadBalancer endpoints
kubectl get services -n chatbot -o wide

# Port forward for local testing (optional)
kubectl port-forward svc/backend-service 8000:8000 -n chatbot
kubectl port-forward svc/frontend-service 3000:80 -n chatbot

# Access at:
# http://localhost:3000     (Frontend)
# http://localhost:8000     (Backend API)
# http://localhost:8000/docs (API Documentation)

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# Check cluster info
kubectl cluster-info

# Get pods with detailed info
kubectl get pods -n chatbot -o wide

# Describe a pod for events
kubectl describe pod -n chatbot <pod-name>

# View all events
kubectl get events -n chatbot --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n chatbot

# Delete a deployment
kubectl delete deployment backend -n chatbot

# Delete namespace and all resources
kubectl delete namespace chatbot

# ============================================================================
# CLEANUP (when done testing)
# ============================================================================

# Delete Kubernetes namespace
kubectl delete namespace chatbot

# Delete ECR repositories
aws ecr delete-repository --repository-name "ai-chatbot/backend" --force --region ap-southeast-2
aws ecr delete-repository --repository-name "ai-chatbot/frontend" --force --region ap-southeast-2

# Delete EKS cluster (takes 10-15 minutes)
aws eks delete-cluster --name ai-chatbot-cluster --region ap-southeast-2

# Delete node group
aws eks delete-nodegroup --cluster-name ai-chatbot-cluster --nodegroup-name ai-chatbot-node-group --region ap-southeast-2

# Delete VPC and related resources
aws ec2 delete-vpc --vpc-id vpc-0b01101882c5a3e0a --region ap-southeast-2
