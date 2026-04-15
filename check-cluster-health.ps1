##############################################################################
# EKS Cluster Health Check & Fix
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster"
)

Write-Host "`n=== EKS Cluster Health Check ===" -ForegroundColor Yellow
Write-Host ""

# Check addons
Write-Host "1. Checking required addons..." -ForegroundColor Cyan
$addons = aws eks list-addons --cluster-name $ClusterName --region $Region --output json 2>&1 | ConvertFrom-Json

$requiredAddons = @("vpc-cni", "coredns", "kube-proxy")
$missingAddons = @()

foreach ($addon in $requiredAddons) {
    if ($addons.addons -contains $addon) {
        Write-Host "  ✓ $addon installed" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $addon MISSING" -ForegroundColor Red
        $missingAddons += $addon
    }
}

if ($missingAddons.Count -gt 0) {
    Write-Host "`n2. Installing missing addons..." -ForegroundColor Yellow
    foreach ($addon in $missingAddons) {
        Write-Host "  Installing $addon..." -ForegroundColor Cyan
        aws eks create-addon --cluster-name $ClusterName --addon-name $addon `
            --region $Region 2>&1 | Out-Null
        Write-Host "    ✓ $addon queued for installation" -ForegroundColor Green
    }
    Write-Host "`n  Addons may take 2-5 minutes to become active" -ForegroundColor Gray
} else {
    Write-Host "`n  All required addons installed!" -ForegroundColor Green
}

# Check node group
Write-Host "`n3. Checking node group..." -ForegroundColor Cyan
$ng = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ClusterName-node-group" `
    --region $Region --output json 2>&1 | ConvertFrom-Json

if ($ng.nodegroup) {
    Write-Host "  Status: $($ng.nodegroup.status)" -ForegroundColor Cyan
    
    if ($ng.nodegroup.health.issues) {
        Write-Host "  Issues found:" -ForegroundColor Red
        $ng.nodegroup.health.issues | ForEach-Object {
            Write-Host "    - $($_.code): $($_.message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  No health issues reported" -ForegroundColor Green
    }
} else {
    Write-Host "  Node group not found" -ForegroundColor Red
}

# Try to get nodes
Write-Host "`n4. Attempting to query nodes..." -ForegroundColor Cyan
$nodeOutput = kubectl get nodes 2>&1
if ($nodeOutput -and $nodeOutput -notlike "*error*" -and $nodeOutput -notlike "*refused*") {
    Write-Host "  Nodes found:" -ForegroundColor Green
    Write-Host $nodeOutput -ForegroundColor Gray
} else {
    Write-Host "  Could not retrieve nodes - cluster API may not be responding yet" -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Yellow
if ($missingAddons.Count -gt 0) {
    Write-Host "Missing addons were installed. Nodes should become healthy within 5 minutes." -ForegroundColor Cyan
    Write-Host "Check status: aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $ClusterName-node-group --region $Region --query 'nodegroup.status'" -ForegroundColor Gray
} else {
    Write-Host "All addons present. If nodes are still unhealthy:" -ForegroundColor Yellow
    Write-Host "  1. Check EC2 system logs for bootstrap errors" -ForegroundColor Gray
    Write-Host "  2. Verify security group allows internal communication" -ForegroundColor Gray
    Write-Host "  3. Check IAM role has required permissions" -ForegroundColor Gray
}

Write-Host ""
