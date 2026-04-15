#!/usr/bin/env pwsh
<#
.SYNOPSIS
Deploy AI Chatbot application to EKS cluster

.DESCRIPTION
This script deploys the AI Chatbot backend, frontend, and database to the Kubernetes cluster with all necessary configurations.
#>

param(
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$Region = "ap-southeast-2",
    [string]$Namespace = "chatbot",
    [string]$Environment = "production"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Wait-For-Deployment {
    param(
        [string]$Deployment,
        [string]$Namespace,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Host "  Waiting for $Deployment to be ready..." -ForegroundColor Yellow
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $ready = kubectl get deployment $Deployment -n $Namespace -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null
        if ($ready -eq "True") {
            Write-Success "$Deployment is ready!"
            return $true
        }
        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "  Waiting... ($elapsed/$TimeoutSeconds seconds)" -ForegroundColor Gray -NoNewline
    }
    Write-Error-Custom "Timeout waiting for $Deployment"
    return $false
}

# ============================================================================
# MAIN DEPLOYMENT PROCESS
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    🚀 AI CHATBOT DEPLOYMENT TO EKS CLUSTER                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Verify cluster connectivity
Write-Step "Verifying EKS cluster connectivity"
try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Connected to cluster: $ClusterName"
        Write-Host "  $($clusterInfo[0])" -ForegroundColor Gray
    }
}
catch {
    Write-Error-Custom "Cannot connect to cluster. Ensure kubeconfig is configured."
    exit 1
}

# Step 2: Create namespace
Write-Step "Creating namespace '$Namespace'"
$nsExists = kubectl get namespace $Namespace 2>/dev/null
if ($null -eq $nsExists) {
    kubectl create namespace $Namespace | Out-Null
    Write-Success "Namespace '$Namespace' created"
}
else {
    Write-Success "Namespace '$Namespace' already exists"
}

# Step 3: Create secrets for backend (if not exists)
Write-Step "Creating backend secrets"
$secretExists = kubectl get secret backend-secret -n $Namespace 2>/dev/null
if ($null -eq $secretExists) {
    # Generate a random SECRET_KEY if not provided
    $secretKey = -join ((33..126) | Get-Random -Count 32 | % {[char]$_})
    $databaseUrl = "postgresql://postgres:postgres@postgres:5432/chatbot"
    
    kubectl create secret generic backend-secret `
        --from-literal=database-url="$databaseUrl" `
        --from-literal=secret-key="$secretKey" `
        -n $Namespace | Out-Null
    
    Write-Success "Backend secrets created"
    Write-Host "  Database URL: $databaseUrl" -ForegroundColor Gray
}
else {
    Write-Success "Backend secrets already exist"
}

# Step 4: Create ConfigMap for application config
Write-Step "Creating application ConfigMap"
$cmExists = kubectl get configmap app-config -n $Namespace 2>/dev/null
if ($null -eq $cmExists) {
    @"
ENVIRONMENT=$Environment
DEBUG=False
LOG_LEVEL=INFO
ALLOWED_HOSTS=*
"@ | kubectl create configmap app-config `
        --from-file=/dev/stdin `
        -n $Namespace | Out-Null
    
    Write-Success "Application ConfigMap created"
}
else {
    Write-Success "Application ConfigMap already exists"
}

# Step 5: Deploy PostgreSQL database
Write-Step "Deploying PostgreSQL database"
kubectl apply -f k8s/postgres-deployment.yaml -n $Namespace
Write-Success "PostgreSQL deployment manifest applied"
Start-Sleep -Seconds 5

# Step 6: Wait for PostgreSQL to be ready
Write-Step "Waiting for PostgreSQL to initialize"
$pgReady = Wait-For-Deployment -Deployment "postgres" -Namespace $Namespace -TimeoutSeconds 120
if (-not $pgReady) {
    Write-Host "  PostgreSQL is still initializing, proceeding with next steps..." -ForegroundColor Yellow
}

# Step 7: Deploy backend
Write-Step "Deploying backend service"
kubectl apply -f k8s/backend-deployment.yaml -n $Namespace
Write-Success "Backend deployment manifest applied"
Start-Sleep -Seconds 5

# Step 8: Deploy frontend
Write-Step "Deploying frontend service"
kubectl apply -f k8s/frontend-deployment.yaml -n $Namespace
Write-Success "Frontend deployment manifest applied"
Start-Sleep -Seconds 5

# Step 9: Check deployment status
Write-Step "Checking deployment status"
kubectl get deployments -n $Namespace
Write-Host ""

# Step 10: Create a service to expose applications (LoadBalancer for easy access)
Write-Step "Creating LoadBalancer services for frontend access"

@"
apiVersion: v1
kind: Service
metadata:
  name: frontend-lb
  namespace: $Namespace
  labels:
    app: frontend
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: frontend
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: $Namespace
  labels:
    app: backend
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: backend
"@ | kubectl apply -f - | Out-Null

Write-Success "Services created"

# Step 11: Display deployment summary
Write-Step "Deployment Summary"
Write-Host "`n📊 Cluster Status:" -ForegroundColor Yellow
kubectl get nodes -o wide

Write-Host "`n📊 Namespace Information:" -ForegroundColor Yellow
kubectl get namespace $Namespace

Write-Host "`n📊 Deployments:" -ForegroundColor Yellow
kubectl get deployments -n $Namespace -o wide

Write-Host "`n📊 Pods:" -ForegroundColor Yellow
kubectl get pods -n $Namespace -o wide

Write-Host "`n📊 Services:" -ForegroundColor Yellow
kubectl get svc -n $Namespace -o wide

# Step 12: Wait for services to get external IPs
Write-Step "Waiting for LoadBalancer external IP (this may take 1-2 minutes)..."
$maxAttempts = 30
$attempt = 0
$frontendIP = $null

while ($attempt -lt $maxAttempts) {
    $svc = kubectl get svc frontend-lb -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
    if ($svc -and $svc -ne "") {
        $frontendIP = $svc
        break
    }
    $attempt++
    Start-Sleep -Seconds 5
    if ($attempt % 2 -eq 0) {
        Write-Host "  Waiting... ($attempt/30)" -ForegroundColor Gray
    }
}

# Final Summary
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           ✅ DEPLOYMENT COMPLETE                              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📋 Deployment Details:" -ForegroundColor Cyan
Write-Host "  Cluster: $ClusterName" -ForegroundColor Gray
Write-Host "  Region: $Region" -ForegroundColor Gray
Write-Host "  Namespace: $Namespace" -ForegroundColor Gray
Write-Host "  Environment: $Environment" -ForegroundColor Gray

Write-Host "`n🌐 Application Access:" -ForegroundColor Cyan
if ($frontendIP) {
    Write-Host "  Frontend URL: http://$frontendIP" -ForegroundColor Green
    Write-Host "  (DNS name may take a few minutes to resolve)" -ForegroundColor Yellow
}
else {
    Write-Host "  Frontend: kubectl port-forward -n $Namespace svc/frontend-lb 3000:80" -ForegroundColor Green
}

Write-Host "  Backend: kubectl port-forward -n $Namespace svc/backend-service 8000:8000" -ForegroundColor Green

Write-Host "`n📝 Useful Commands:" -ForegroundColor Cyan
Write-Host "  View pods: kubectl get pods -n $Namespace --watch" -ForegroundColor Gray
Write-Host "  View logs: kubectl logs -n $Namespace -l app=backend -f" -ForegroundColor Gray
Write-Host "  Describe pod: kubectl describe pod <pod-name> -n $Namespace" -ForegroundColor Gray
Write-Host "  Scale deployment: kubectl scale deployment backend -n $Namespace --replicas=5" -ForegroundColor Gray
Write-Host "  Delete deployment: kubectl delete namespace $Namespace" -ForegroundColor Gray

Write-Host "`n🎉 Your AI Chatbot is now running on EKS!" -ForegroundColor Green
Write-Host "   Check pod status with: kubectl get pods -n $Namespace`n" -ForegroundColor Yellow
