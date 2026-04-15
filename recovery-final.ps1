##############################################################################
# Final Node Group Recovery with Subnet Routing Fix
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$ProjectName = "ai-chatbot"
)

Write-Host "`n=== FINAL NODE GROUP RECOVERY ===" -ForegroundColor Green
Write-Host "Ensuring subnets are properly routed to IGW...`n" -ForegroundColor Cyan

# Step 1: Verify routing is in place
Write-Host "Step 1: Verifying subnet routing..." -ForegroundColor Yellow
$rt = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0b01101882c5a3e0a" `
    --region ap-southeast-2 --query "RouteTables[0].RouteTableId" --output text 2>&1

if ($rt) {
    $route = aws ec2 describe-route-tables --route-table-ids $rt --region ap-southeast-2 `
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" --output text 2>&1
    
    if ($route -and $route -ne "None") {
        Write-Host "  ✓ IGW route exists: $route`n" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: No IGW route found`n" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Delete existing node group
Write-Host "Step 2: Deleting existing node group..." -ForegroundColor Yellow
$status = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --region $Region --query 'nodegroup.status' --output text 2>&1

if ($status -and -not ($status -like "*ResourceNotFoundException*")) {
    aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
        --region $Region 2>&1 | Out-Null
    
    Write-Host "  Waiting for deletion..." -ForegroundColor Gray
    $wait = 0
    while ($wait -lt 60) {
        $check = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
            --region $Region --query 'nodegroup.status' --output text 2>&1
        
        if ($check -like "*ResourceNotFoundException*") {
            Write-Host "  OK - Deleted`n" -ForegroundColor Green
            break
        }
        Start-Sleep -Seconds 5
        $wait += 5
    }
}

# Step 3: Get resources
Write-Host "Step 3: Gathering AWS resources..." -ForegroundColor Yellow
$cluster = aws eks describe-cluster --name $ClusterName --region $Region --output json 2>&1 | ConvertFrom-Json
$subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$($cluster.cluster.resourcesVpcConfig.vpcId)" `
    --region $Region --output json 2>&1 | ConvertFrom-Json | Select-Object -ExpandProperty Subnets

$publicSubnets = @()
foreach ($subnet in $subnets) {
    if ($subnet.MapPublicIpOnLaunch -eq $true) {
        $publicSubnets += $subnet.SubnetId
    }
}

$nodeRole = aws iam get-role --role-name "$ProjectName-eks-node-group-role" --output json 2>&1 | ConvertFrom-Json

Write-Host "  Subnets: $($publicSubnets -join ', ')" -ForegroundColor Cyan
Write-Host "  Node Role: $($nodeRole.Role.Arn)" -ForegroundColor Cyan
Write-Host "  Cluster: ACTIVE`n" -ForegroundColor Cyan

# Step 4: Create new node group
Write-Host "Step 4: Creating node group (t3.small)..." -ForegroundColor Yellow
aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --subnets $publicSubnets --node-role $nodeRole.Role.Arn `
    --scaling-config minSize=2,maxSize=5,desiredSize=2 `
    --instance-types t3.small --region $Region 2>&1 | Out-Null

Write-Host "  ✓ Creation initiated`n" -ForegroundColor Green

# Step 5: Monitor
Write-Host "Step 5: Monitoring (this may take 10-15 minutes)..." -ForegroundColor Yellow
$elapsed = 0
$lastStatus = ""

while ($elapsed -lt 1200) {
    $status = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
        --region $Region --query 'nodegroup.status' --output text 2>&1
    
    if ($status -ne $lastStatus -and $status -ne "CREATING") {
        Write-Host "  Status: $status" -ForegroundColor Cyan
        $lastStatus = $status
    } elseif ($status -eq "CREATING" -and ($elapsed % 60 -eq 0)) {
        Write-Host "  [$elapsed s] Still creating..." -ForegroundColor Gray
        $lastStatus = $status
    }
    
    if ($status -eq "ACTIVE") {
        Write-Host "`n  *** NODES ACTIVE ***`n" -ForegroundColor Green
        break
    } elseif ($status -like "*FAILED*") {
        Write-Host "`n  ERROR: FAILED`n" -ForegroundColor Red
        exit 1
    }
    
    Start-Sleep -Seconds 30
    $elapsed += 30
}

if ($elapsed -ge 1200) {
    Write-Host "Timeout - check: aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $ProjectName-node-group --region $Region`n" -ForegroundColor Yellow
    exit 1
}

# Step 6: Verify nodes
Write-Host "Step 6: Verifying nodes joined cluster..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$nodes = kubectl get nodes 2>&1
Write-Host $nodes -ForegroundColor Green

Write-Host ""
Write-Host "=== RECOVERY COMPLETE ===" -ForegroundColor Green
Write-Host "Next: .\build-and-push-images.ps1" -ForegroundColor Cyan
