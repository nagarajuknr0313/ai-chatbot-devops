##############################################################################
# Deploy to Kubernetes Cluster
# Script to deploy applications to EKS cluster
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$Namespace = "chatbot",
    [string]$AccountId = "868987408656"
)

function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Header { Write-Host "`n► $args" -ForegroundColor Cyan }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Yellow }
function Write-Section { Write-Host "`n$args" -ForegroundColor Yellow; Write-Host $([string]::new('─', $args.Length)) -ForegroundColor Gray }

Write-Header "╔════════════════════════════════════════════════════════╗"
Write-Host "║        Kubernetes Deployment Script                    ║"
Write-Host "║        Cluster: $ClusterName                      ║"
Write-Host "║        Region: $Region                            ║"
Write-Host "║        Namespace: $Namespace                           ║"
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Verify kubectl connectivity
Write-Header "Step 1: Verifying kubectl Connectivity"
Write-Host "Checking cluster access..."

try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Connected to Kubernetes cluster"
        Write-Host $clusterInfo | Select-Object -First 2
    } else {
        Write-Error "Cannot connect to Kubernetes cluster"
        Write-Host "Run: aws eks update-kubeconfig --region $Region --name $ClusterName"
        exit 1
    }
}
catch {
    Write-Error "kubectl error: $_"
    exit 1
}

# Step 2: Verify nodes are ready
Write-Header "Step 2: Checking Node Status"

$nodes = kubectl get nodes --no-headers 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host $nodes
    
    $readyNodes = $nodes | Select-String "Ready" | Measure-Object | Select-Object -ExpandProperty Count
    if ($readyNodes -ge 2) {
        Write-Success "All nodes are ready ($readyNodes nodes)"
    } else {
        Write-Info "Waiting for nodes to be ready ($readyNodes/2 ready)..."
        Write-Host "  This may take another 2-5 minutes for nodes to initialize"
    }
} else {
    Write-Error "Failed to get node status"
    exit 1
}

# Step 3: Create namespace
Write-Header "Step 3: Creating Kubernetes Namespace and ConfigMap"
Write-Host "Creating namespace: $Namespace..."

kubectl apply -f "k8s/namespace.yaml" --region=$Region 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Success "Namespace created/updated"
} else {
    Write-Error "Failed to create namespace"
    exit 1
}

# Step 4: Create secrets for database and API keys
Write-Header "Step 4: Creating Kubernetes Secrets"

# Check if secrets already exist
$existingSecrets = kubectl get secret -n $Namespace --no-headers 2>&1
if ($existingSecrets -like "*database-secret*") {
    Write-Info "Database secret already exists (skipping)"
} else {
    Write-Host "Creating database credentials secret..."
    
    # Create random password if not set
    $dbPassword = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { [System.Guid]::NewGuid().ToString() }
    
    kubectl create secret generic database-secret `
        --from-literal=password=$dbPassword `
        --from-literal=username=chatbot `
        --from-literal=dbname=chatbot_db `
        -n $Namespace 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database secret created"
        Write-Host "  Database Password: $dbPassword (save this for later)"
    } else {
        Write-Error "Failed to create database secret"
    }
}

# Create API keys secret
if ($existingSecrets -like "*api-keys*") {
    Write-Info "API keys secret already exists (skipping)"
} else {
    Write-Host "Creating API keys secret..."
    
    $apiKey = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "your-openai-api-key" }
    $jwtSecret = [System.Guid]::NewGuid().ToString()
    
    kubectl create secret generic api-keys `
        --from-literal=openai_api_key=$apiKey `
        --from-literal=jwt_secret=$jwtSecret `
        -n $Namespace 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "API keys secret created"
        Write-Host "  Note: Update OPENAI_API_KEY in the secret if needed"
    }
}

# Step 5: Deploy backend
Write-Header "Step 5: Deploying Backend Application"
Write-Host "Deploying backend service..."

$backendImage = "$AccountId.dkr.ecr.$Region.amazonaws.com/ai-chatbot/backend:latest"

# Update the deployment YAML with the image
$backendYaml = Get-Content "k8s/backend-deployment.yaml" -Raw
$backendYaml = $backendYaml -replace 'image: .*?/backend:.*', "image: $backendImage"
$backendYaml | kubectl apply -f - 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Backend deployment created/updated"
} else {
    Write-Error "Failed to deploy backend"
}

# Step 6: Deploy frontend
Write-Header "Step 6: Deploying Frontend Application"
Write-Host "Deploying frontend service..."

$frontendImage = "$AccountId.dkr.ecr.$Region.amazonaws.com/ai-chatbot/frontend:latest"

# Update the deployment YAML with the image
$frontendYaml = Get-Content "k8s/frontend-deployment.yaml" -Raw
$frontendYaml = $frontendYaml -replace 'image: .*?/frontend:.*', "image: $frontendImage"
$frontendYaml | kubectl apply -f - 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Frontend deployment created/updated"
} else {
    Write-Error "Failed to deploy frontend"
}

# Step 7: Wait for deployments to be ready
Write-Header "Step 7: Waiting for Deployments to be Ready"
Write-Info "This may take 2-5 minutes..."

$maxWait = 300  # 5 minutes
$elapsed = 0

while ($elapsed -lt $maxWait) {
    $backendReady = kubectl get deployment backend -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>&1
    $frontendReady = kubectl get deployment frontend -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>&1
    
    Write-Host "  Backend: $backendReady/1, Frontend: $frontendReady/1 ready (${elapsed}s)" -ForegroundColor Gray
    
    if ($backendReady -eq "1" -and $frontendReady -eq "1") {
        Write-Success "All deployments are ready!"
        break
    }
    
    Start-Sleep -Seconds 10
    $elapsed += 10
}

# Step 8: Verify pod status
Write-Header "Step 8: Verifying Pod Status"

$pods = kubectl get pods -n $Namespace --no-headers 2>&1
Write-Host $pods

$failedPods = $pods | Select-String -Pattern "0/1|CrashLoop|Error" | Measure-Object | Select-Object -ExpandProperty Count
if ($failedPods -gt 0) {
    Write-Error "Some pods failed to start. Check logs with: kubectl logs -n $Namespace pod/<pod-name>"
}

# Step 9: Check services
Write-Header "Step 9: Checking Services and Endpoints"

$services = kubectl get services -n $Namespace 2>&1
Write-Host $services

# Step 10: Display access information
Write-Header "Step 10: Access Information"

$backendService = kubectl get service backend-service -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>&1
$frontendService = kubectl get service frontend-service -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>&1

Write-Host @"
╔════════════════════════════════════════════════════════╗
║      Deployment Successfully Completed!               ║
╚════════════════════════════════════════════════════════╝

SERVICES DEPLOYED:
  Backend Service:  http://$backendService:8000
  Frontend Service: http://$frontendService:3000

TO ACCESS YOUR APPLICATION:

  Option 1: Using LoadBalancer (recommended)
    - Frontend: http://$frontendService
    - Backend API: http://$backendService:8000
    - Backend Docs: http://$backendService:8000/docs

  Option 2: Using Port Forwarding (for testing)
    # In separate terminals:
    kubectl port-forward -n $Namespace svc/frontend-service 3000:80
    kubectl port-forward -n $Namespace svc/backend-service 8000:8000
    
    # Access at:
    # Frontend: http://localhost:3000
    # Backend: http://localhost:8000

  Option 3: Using kubectl Proxy
    kubectl proxy
    # Frontend: http://localhost:8001/api/v1/namespaces/$Namespace/services/frontend-service/proxy
    # Backend: http://localhost:8001/api/v1/namespaces/$Namespace/services/backend-service/proxy

MONITORING:

  View Pod Logs:
    kubectl logs -n $Namespace deployment/backend -f
    kubectl logs -n $Namespace deployment/frontend -f
  
  Pod Status:
    kubectl get pods -n $Namespace
    kubectl describe pod -n $Namespace <pod-name>
  
  Events:
    kubectl get events -n $Namespace --sort-by='.lastTimestamp'
  
  Resource Usage:
    kubectl top nodes
    kubectl top pods -n $Namespace

SCALING:

  Scale Backend:
    kubectl scale deployment backend --replicas=3 -n $Namespace
  
  Scale Frontend:
    kubectl scale deployment frontend --replicas=3 -n $Namespace

CLEANUP (when done):

  Delete all resources:
    kubectl delete namespace $Namespace

  Delete individual resources:
    kubectl delete deployment backend -n $Namespace
    kubectl delete deployment frontend -n $Namespace
    kubectl delete service backend-service -n $Namespace
    kubectl delete service frontend-service -n $Namespace

"@ -ForegroundColor Green

Write-Info "Deployment complete! Your application is now running on AWS EKS."
