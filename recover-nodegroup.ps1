##############################################################################
# Recover from Node Group Failure - Create New Node Group
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$ProjectName = "ai-chatbot",
    [string]$InstanceType = "t3.small"
)

Write-Host "=== EKS Node Group Recovery ===" -ForegroundColor Yellow
Write-Host "Using Instance Type: $InstanceType`n" -ForegroundColor Cyan

# Step 1: Delete failed node group
Write-Host "Step 1: Deleting failed node group..." -ForegroundColor Yellow
aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --region $Region 2>&1 | Out-Null

Write-Host "  Waiting for deletion..." -ForegroundColor Gray
$elapsed = 0
while ($elapsed -lt 600) {
    $status = aws eks describe-nodegroup --cluster-name $ClusterName `
        --nodegroup-name "$ProjectName-node-group" --region $Region `
        --query 'nodegroup.status' --output text 2>&1
    
    if ($status -like "*ResourceNotFoundException*" -or $status -like "*not found*") {
        Write-Host "  Deleted successfully`n" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 15
    $elapsed += 15
}

# Step 2: Get VPC details
Write-Host "Step 2: Getting VPC configuration..." -ForegroundColor Yellow
$cluster = aws eks describe-cluster --name $ClusterName --region $Region `
    --output json 2>&1 | ConvertFrom-Json

$VpcId = $cluster.cluster.resourcesVpcConfig.vpcId
Write-Host "  VPC: $VpcId`n" -ForegroundColor Green

# Step 3: Get public subnets
Write-Host "Step 3: Selecting public subnets..." -ForegroundColor Yellow
$subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" `
    --region $Region --output json 2>&1 | ConvertFrom-Json | Select-Object -ExpandProperty Subnets

$publicSubnets = @()
foreach ($subnet in $subnets) {
    if ($subnet.MapPublicIpOnLaunch -eq $true) {
        $publicSubnets += $subnet.SubnetId
        Write-Host "  Added: $($subnet.SubnetId) ($($subnet.CidrBlock))" -ForegroundColor Cyan
    }
}

if ($publicSubnets.Count -eq 0) {
    Write-Host "ERROR: No public subnets found!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 4: Get node role
Write-Host "Step 4: Getting IAM node role..." -ForegroundColor Yellow
$nodeRole = aws iam get-role --role-name "$ProjectName-eks-node-group-role" `
    --output json 2>&1 | ConvertFrom-Json

if (-not $nodeRole.Role) {
    Write-Host "ERROR: Node role not found!" -ForegroundColor Red
    exit 1
}
$nodeRoleArn = $nodeRole.Role.Arn
Write-Host "  Role: $nodeRoleArn`n" -ForegroundColor Green

# Step 5: Create new node group
Write-Host "Step 5: Creating new node group..." -ForegroundColor Yellow
Write-Host "  Instance Type: $InstanceType" -ForegroundColor Gray
Write-Host "  Min/Desired/Max: 2/2/5" -ForegroundColor Gray
Write-Host "  Subnets: $($publicSubnets -join ', ')`n" -ForegroundColor Gray

aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --subnets $publicSubnets --node-role $nodeRoleArn `
    --scaling-config minSize=2,maxSize=5,desiredSize=2 `
    --instance-types $InstanceType --region $Region 2>&1 | Out-Null

Write-Host "Node group creation initiated`n" -ForegroundColor Green

# Step 6: Monitor creation
Write-Host "Step 6: Monitoring node group creation..." -ForegroundColor Yellow
$maxWait = 1200
$elapsed = 0
$lastStatus = ""

while ($elapsed -lt $maxWait) {
    $status = aws eks describe-nodegroup --cluster-name $ClusterName `
        --nodegroup-name "$ProjectName-node-group" --region $Region `
        --query 'nodegroup.status' --output text 2>&1
    
    if ($status -ne $lastStatus) {
        Write-Host "  [$elapsed s] Status: $status" -ForegroundColor Cyan
        $lastStatus = $status
    }
    
    if ($status -eq "ACTIVE") {
        Write-Host "`n*** NODE GROUP ACTIVE ***`n" -ForegroundColor Green
        break
    } elseif ($status -like "*FAILED*") {
        Write-Host "`nERROR: Node group creation FAILED`n" -ForegroundColor Red
        $ngData = aws eks describe-nodegroup --cluster-name $ClusterName `
            --nodegroup-name "$ProjectName-node-group" --region $Region --output json 2>&1 | ConvertFrom-Json
        if ($ngData.nodegroup.health.issues) {
            Write-Host "Issues:" -ForegroundColor Yellow
            $ngData.nodegroup.health.issues | ForEach-Object {
                Write-Host "  - $($_.message)" -ForegroundColor Red
            }
        }
        exit 1
    }
    
    Start-Sleep -Seconds 30
    $elapsed += 30
}

if ($elapsed -ge $maxWait) {
    Write-Host "ERROR: Timeout waiting for node group to reach ACTIVE`n" -ForegroundColor Red
    exit 1
}

# Step 7: Verify nodes joined cluster
Write-Host "Step 7: Verifying nodes joined cluster..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$nodes = kubectl get nodes -o wide 2>&1

if ($nodes -and $nodes -notlike "*error*" -and $nodes -notlike "*refused*") {
    Write-Host "Nodes joined successfully:`n" -ForegroundColor Green
    Write-Host $nodes -ForegroundColor Cyan
} else {
    Write-Host "WARNING: Could not verify nodes with kubectl`n" -ForegroundColor Yellow
    Write-Host "Check manually with: kubectl get nodes`n" -ForegroundColor Gray
}

Write-Host "=== RECOVERY COMPLETE ===" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Verify nodes are ready: kubectl get nodes" -ForegroundColor Gray
Write-Host "  2. Build images: .\build-and-push-images.ps1" -ForegroundColor Gray
Write-Host "  3. Deploy app: .\deploy-to-kubernetes.ps1" -ForegroundColor Gray
