##############################################################################
# Check EKS Node Group Status and Configuration
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$NodeGroupName = "ai-chatbot-node-group"
)

Write-Host "=== EKS Node Group Status Check ===" -ForegroundColor Yellow
Write-Host ""

# Check node group status
Write-Host "Checking node group status..." -ForegroundColor Cyan
$ng = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
    --region $Region --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($ng.nodegroup) {
    Write-Host "Node Group: $($ng.nodegroup.nodegroupName)" -ForegroundColor Green
    Write-Host "Status: $($ng.nodegroup.status)" -ForegroundColor Yellow
    Write-Host "Created: $($ng.nodegroup.createdAt)" -ForegroundColor Gray
    Write-Host "Modified: $($ng.nodegroup.modifiedAt)" -ForegroundColor Gray
    Write-Host ""
    
    # Check health issues
    if ($ng.nodegroup.health.issues.Count -gt 0) {
        Write-Host "HEALTH ISSUES FOUND:" -ForegroundColor Red
        foreach ($issue in $ng.nodegroup.health.issues) {
            Write-Host "  Code: $($issue.code)" -ForegroundColor Red
            Write-Host "  Message: $($issue.message)" -ForegroundColor Yellow
            if ($issue.resourceIds) {
                Write-Host "  Resources: $($issue.resourceIds -join ', ')" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No health issues" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Instance Type: $($ng.nodegroup.instanceTypes -join ', ')" -ForegroundColor Gray
    Write-Host "  Min Size: $($ng.nodegroup.scalingConfig.minSize)" -ForegroundColor Gray
    Write-Host "  Max Size: $($ng.nodegroup.scalingConfig.maxSize)" -ForegroundColor Gray
    Write-Host "  Desired: $($ng.nodegroup.scalingConfig.desiredSize)" -ForegroundColor Gray
    Write-Host "  Subnets: $($ng.nodegroup.subnets -join ', ')" -ForegroundColor Gray
    Write-Host "  Node Role: $($ng.nodegroup.nodeRole)" -ForegroundColor Gray
} else {
    Write-Host "ERROR: Could not get node group info" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Subnet Details ===" -ForegroundColor Yellow
$subnets = aws ec2 describe-subnets --subnet-ids $ng.nodegroup.subnets --region $Region `
    --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($subnets.Subnets) {
    foreach ($subnet in $subnets.Subnets) {
        $type = if ($subnet.MapPublicIpOnLaunch) { "PUBLIC" } else { "PRIVATE" }
        Write-Host "  $($subnet.SubnetId) [$type] $($subnet.CidrBlock) Zone: $($subnet.AvailabilityZone)" -ForegroundColor Gray
    }
} else {
    Write-Host "ERROR: Could not get subnet info" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Security Group ===" -ForegroundColor Yellow
$cluster = aws eks describe-cluster --name $ClusterName --region $Region `
    --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($cluster.cluster) {
    $sgId = $cluster.cluster.resourcesVpcConfig.clusterSecurityGroupId
    Write-Host "Security Group: $sgId" -ForegroundColor Cyan
    
    $sg = aws ec2 describe-security-groups --group-ids $sgId --region $Region `
        --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($sg.SecurityGroups) {
        $sgData = $sg.SecurityGroups[0]
        
        if ($sgData.IpPermissions.Count -eq 0) {
            Write-Host "WARNING: NO INGRESS RULES! This prevents node communication." -ForegroundColor Red
        } else {
            Write-Host "Ingress Rules: $($sgData.IpPermissions.Count) rules" -ForegroundColor Green
        }
        
        Write-Host "Egress Rules: $($sgData.IpPermissionsEgress.Count) rules" -ForegroundColor Green
    }
} else {
    Write-Host "ERROR: Could not get cluster info" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Recommended Actions ===" -ForegroundColor Cyan
Write-Host ""

if ($ng.nodegroup.status -eq "CREATE_FAILED") {
    Write-Host "Node Group FAILED. Options:" -ForegroundColor Yellow
    Write-Host "  1. Delete and retry with different config:" -ForegroundColor Gray
    Write-Host "     aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Try t3.small instead of t3.medium" -ForegroundColor Gray
    Write-Host "  3. Verify security group has ingress rules" -ForegroundColor Gray
    Write-Host "  4. Ensure subnets have internet access" -ForegroundColor Gray
} elseif ($ng.nodegroup.status -eq "ACTIVE") {
    Write-Host "Node Group is ACTIVE. Checking nodes..." -ForegroundColor Green
    kubectl get nodes -o wide
} else {
    Write-Host "Node Group Status: $($ng.nodegroup.status)" -ForegroundColor Yellow
    Write-Host "Waiting for status to change..." -ForegroundColor Gray
}
