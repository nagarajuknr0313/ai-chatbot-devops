#!/usr/bin/env pwsh

param(
    [string]$Region = "ap-southeast-2",
    [string]$AccountID = "868987408656"
)

$ErrorActionPreference = "Stop"

# Colors for output
$Green = @{ ForegroundColor = 'Green' }
$Yellow = @{ ForegroundColor = 'Yellow' }
$Cyan = @{ ForegroundColor = 'Cyan' }

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" @Cyan
Write-Host "║     🐳 BUILD AND PUSH TO ECR                                 ║" @Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" @Cyan

# ECR Registry URLs
$BackendRepo = "$AccountID.dkr.ecr.$Region.amazonaws.com/chatbot-backend"
$FrontendRepo = "$AccountID.dkr.ecr.$Region.amazonaws.com/chatbot-frontend"

Write-Host "📋 Configuration:" @Yellow
Write-Host "  Region: $Region" -ForegroundColor Gray
Write-Host "  Account: $AccountID" -ForegroundColor Gray
Write-Host "  Backend: $BackendRepo" -ForegroundColor Gray
Write-Host "  Frontend: $FrontendRepo" -ForegroundColor Gray

# Create ECR repositories if they don't exist
Write-Host "`n1️⃣  Creating ECR repositories..." @Yellow

try {
    aws ecr describe-repositories --repository-names chatbot-backend --region $Region 2>$null
    Write-Host "  ✅ Backend repository exists" @Green
}
catch {
    Write-Host "  📦 Creating backend repository..." -ForegroundColor Gray
    aws ecr create-repository --repository-name chatbot-backend --region $Region | Out-Null
    Write-Host "  ✅ Backend repository created" @Green
}

try {
    aws ecr describe-repositories --repository-names chatbot-frontend --region $Region 2>$null
    Write-Host "  ✅ Frontend repository exists" @Green
}
catch {
    Write-Host "  📦 Creating frontend repository..." -ForegroundColor Gray
    aws ecr create-repository --repository-name chatbot-frontend --region $Region | Out-Null
    Write-Host "  ✅ Frontend repository created" @Green
}

# Login to ECR
Write-Host "`n2️⃣  Logging in to ECR..." @Yellow
$ecrPassword = aws ecr get-authorization-token --region $Region --query authorizationData[0].authorizationToken --output text
$ecrUsername = "AWS"
docker login -u $ecrUsername -p $ecrPassword $AccountID.dkr.ecr.$Region.amazonaws.com | Out-Null
Write-Host "  ✅ ECR login successful" @Green

# Build backend image
Write-Host "`n3️⃣  Building backend Docker image..." @Yellow
$backendTagged = "$BackendRepo:latest"
docker build -t $backendTagged ./backend -f ./backend/Dockerfile
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Backend image built" @Green
} else {
    Write-Host "  ❌ Failed to build backend image" -ForegroundColor Red
    exit 1
}

# Build frontend image
Write-Host "`n4️⃣  Building frontend Docker image..." @Yellow
$frontendTagged = "$FrontendRepo:latest"
docker build -t $frontendTagged ./frontend -f ./frontend/Dockerfile
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Frontend image built" @Green
} else {
    Write-Host "  ❌ Failed to build frontend image" -ForegroundColor Red
    exit 1
}

# Push backend image
Write-Host "`n5️⃣  Pushing backend image to ECR..." @Yellow
docker push $backendTagged
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Backend image pushed" @Green
    Write-Host "     $backendTagged" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Failed to push backend image" -ForegroundColor Red
    exit 1
}

# Push frontend image
Write-Host "`n6️⃣  Pushing frontend image to ECR..." @Yellow
docker push $frontendTagged
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Frontend image pushed" @Green
    Write-Host "     $frontendTagged" -ForegroundColor Gray
} else {
    Write-Host "  ❌ Failed to push frontend image" -ForegroundColor Red
    exit 1
}

# Output image URLs for deployment
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" @Green
Write-Host "║            ✅ BUILD AND PUSH COMPLETE                        ║" @Green
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" @Green

Write-Host "📦 ECR Image URLs:" @Yellow
Write-Host "  Backend:  $backendTagged"
Write-Host "  Frontend: $frontendTagged"

Write-Host "`n💡 Next steps:" @Cyan
Write-Host "  Run: kubectl rollout restart deployment backend -n chatbot" -ForegroundColor Gray
Write-Host "  Run: kubectl rollout restart deployment frontend -n chatbot" -ForegroundColor Gray
Write-Host "  Or redeploy with: kubectl apply -f k8s/backend-deployment.yaml -n chatbot" -ForegroundColor Gray
