##############################################################################
# Build and Push Docker Images to ECR
# Script to build and push both backend and frontend images
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$AccountId = "868987408656",
    [string]$ProjectName = "ai-chatbot"
)

function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Header { Write-Host "`n► $args" -ForegroundColor Cyan }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Yellow }

$ECR_REGISTRY = "$AccountId.dkr.ecr.$Region.amazonaws.com"
$BACKEND_REPO = "$ECR_REGISTRY/$ProjectName/backend"
$FRONTEND_REPO = "$ECR_REGISTRY/$ProjectName/frontend"

Write-Header "╔════════════════════════════════════════════════════════╗"
Write-Host "║        Docker Build & Push to ECR                      ║"
Write-Host "║        Region: $Region                            ║"
Write-Host "║        Registry: $ECR_REGISTRY       ║"
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: ECR Login
Write-Header "Step 1: ECR Authentication"
Write-Host "Getting ECR login credentials..."

try {
    $loginPassword = aws ecr get-login-password --region $Region 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get ECR login password"
        exit 1
    }
    
    # Docker login
    $loginPassword | docker login --username AWS --password-stdin $ECR_REGISTRY 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Successfully authenticated with ECR"
    } else {
        Write-Error "Docker login failed"
        exit 1
    }
}
catch {
    Write-Error "Authentication error: $_"
    exit 1
}

# Step 2: Build Backend Image
Write-Header "Step 2: Building Backend Image"
Write-Host "Building Docker image for backend..."
Write-Host "  Repository: $BACKEND_REPO"
Write-Host "  Tag: latest"

try {
    Push-Location "backend"
    
    docker build `
        --tag "$BACKEND_REPO:latest" `
        --tag "$BACKEND_REPO:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --target production `
        --build-arg BUILD_DATE="$(Get-Date -Format 'o')" `
        -f Dockerfile .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Backend image built successfully"
    } else {
        Write-Error "Backend image build failed"
        Pop-Location
        exit 1
    }
    
    Pop-Location
}
catch {
    Write-Error "Build error: $_"
    exit 1
}

# Step 3: Push Backend Image
Write-Header "Step 3: Pushing Backend Image to ECR"
Write-Host "Pushing image to ECR (this may take 2-5 minutes)..."

try {
    docker push "$BACKEND_REPO:latest" 2>&1 | Tee-Object -Variable pushOutput
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Backend image pushed successfully"
        $imageUri = "$BACKEND_REPO@$($pushOutput[-1] | Select-String '(?<=@sha256:)[a-f0-9]+' -o | % { $_.Matches.Value })"
        Write-Host "  Image URI: $BACKEND_REPO:latest"
    } else {
        Write-Error "Backend image push failed"
        exit 1
    }
}
catch {
    Write-Error "Push error: $_"
    exit 1
}

# Step 4: Build Frontend Image
Write-Header "Step 4: Building Frontend Image"
Write-Host "Building Docker image for frontend..."
Write-Host "  Repository: $FRONTEND_REPO"
Write-Host "  Tag: latest"

try {
    Push-Location "frontend"
    
    docker build `
        --tag "$FRONTEND_REPO:latest" `
        --tag "$FRONTEND_REPO:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --build-arg VITE_API_URL="http://backend-service:8000" `
        --build-arg VITE_WS_URL="ws://backend-service:8000/ws" `
        -f Dockerfile .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Frontend image built successfully"
    } else {
        Write-Error "Frontend image build failed"
        Pop-Location
        exit 1
    }
    
    Pop-Location
}
catch {
    Write-Error "Build error: $_"
    exit 1
}

# Step 5: Push Frontend Image
Write-Header "Step 5: Pushing Frontend Image to ECR"
Write-Host "Pushing image to ECR (this may take 2-5 minutes)..."

try {
    docker push "$FRONTEND_REPO:latest" 2>&1 | Tee-Object -Variable pushOutput
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Frontend image pushed successfully"
        Write-Host "  Image URI: $FRONTEND_REPO:latest"
    } else {
        Write-Error "Frontend image push failed"
        exit 1
    }
}
catch {
    Write-Error "Push error: $_"
    exit 1
}

# Verify Images in ECR
Write-Header "Step 6: Verifying Images in ECR"

$backendImages = aws ecr describe-images --repository-name "$ProjectName/backend" --region $Region --query 'imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]' --output text 2>&1
$frontendImages = aws ecr describe-images --repository-name "$ProjectName/frontend" --region $Region --query 'imageDetails[*].[imageTags,imageSizeInBytes,imagePushedAt]' --output text 2>&1

Write-Host "`nBackend Repository:"
Write-Host $backendImages

Write-Host "`nFrontend Repository:"
Write-Host $frontendImages

# Final Summary
Write-Header "✓ BUILD AND PUSH COMPLETE"
Write-Host @"
╔════════════════════════════════════════════════════════╗
║  Docker Images Successfully Built and Pushed!         ║
╚════════════════════════════════════════════════════════╝

BACKEND IMAGE:
  Repository: $BACKEND_REPO
  Tag: latest
  Check: aws ecr describe-images --repository-name $ProjectName/backend --region $Region

FRONTEND IMAGE:
  Repository: $FRONTEND_REPO
  Tag: latest
  Check: aws ecr describe-images --repository-name $ProjectName/frontend --region $Region

NEXT STEPS:
  1. Update k8s/backend-deployment.yaml with image: $BACKEND_REPO:latest
  2. Update k8s/frontend-deployment.yaml with image: $FRONTEND_REPO:latest
  3. Deploy to Kubernetes:
     kubectl apply -f k8s/namespace.yaml
     kubectl apply -f k8s/backend-deployment.yaml
     kubectl apply -f k8s/frontend-deployment.yaml

VERIFY DEPLOYMENT:
  kubectl get pods -n chatbot
  kubectl get services -n chatbot

MONITOR LOGS:
  kubectl logs -n chatbot deployment/backend -f
  kubectl logs -n chatbot deployment/frontend -f
"@ -ForegroundColor Green
