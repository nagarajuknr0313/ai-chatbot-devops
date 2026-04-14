# Simple Deployment Status Monitoring Script (PowerShell)

$CLUSTER = "ai-chatbot-cluster"
$NODEGROUP = "ai-chatbot-node-group"
$REGION = "us-east-1"
$NS = "chatbot"

Write-Host "=== Deployment Status Monitor ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""

# Check Node Group Status
Write-Host "[1] Node Group Status:" -ForegroundColor Yellow
try {
    $ng = (aws eks describe-nodegroup --cluster-name $CLUSTER --nodegroup-name $NODEGROUP --region $REGION --output json | ConvertFrom-Json).nodegroup
    Write-Host "    Status: $($ng.status)" -ForegroundColor Green
    Write-Host "    Desired: $($ng.scalingConfig.desiredSize)"
    Write-Host "    Created: $($ng.createdAt)"
} catch {
    Write-Host "    Error: $_" -ForegroundColor Red
}
Write-Host ""

# Check Pod Status
Write-Host "[2] Pod Status:" -ForegroundColor Yellow
try {
    kubectl get pods -n $NS --no-headers 2>&1 | ForEach-Object { Write-Host "    $_" }
} catch {
    Write-Host "    kubectl not available" -ForegroundColor Yellow
}
Write-Host ""

# Check Services
Write-Host "[3] Services:" -ForegroundColor Yellow
try {
    kubectl get svc -n $NS --no-headers 2>&1 | ForEach-Object { Write-Host "    $_" }
} catch {
    Write-Host "    kubectl not available" -ForegroundColor Yellow
}
Write-Host ""

# Check Deployments
Write-Host "[4] Deployments:" -ForegroundColor Yellow
try {
    kubectl get deployment -n $NS --no-headers 2>&1 | ForEach-Object { Write-Host "    $_" }
} catch {
    Write-Host "    kubectl not available" -ForegroundColor Yellow
}
Write-Host ""

# Check Nodes
Write-Host "[5] Nodes:" -ForegroundColor Yellow
try {
    kubectl get nodes --no-headers 2>&1 | ForEach-Object { Write-Host "    $_" }
} catch {
    Write-Host "    No nodes active yet" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=== Tip: Run again in 2-3 minutes to check progress ===" -ForegroundColor Cyan
