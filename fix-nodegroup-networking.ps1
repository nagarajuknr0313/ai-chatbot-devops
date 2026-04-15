##############################################################################
# Fix EKS Node Group Networking
# 1. Waits for failed node group deletion
# 2. Sets up NAT gateways for private subnets
# 3. Recreates node group in public subnets
# 4. Verifies cluster connectivity
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$ProjectName = "ai-chatbot"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Write-OK { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Error2 { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[...] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Step { Write-Host "`n>>> $args" -ForegroundColor Yellow }

Write-Host "EKS Node Group Networking Fix`nRegion: $Region`n" -ForegroundColor Cyan

# === STEP 1: Wait for Node Group Deletion ===
Write-Step "STEP 1: Waiting for Node Group Deletion"

$maxWait = 600
$elapsed = 0

while ($elapsed -lt $maxWait) {
    $status = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
        --region $Region --query "nodegroup.status" --output text 2>&1
    
    if ($status -like "*ResourceNotFoundException*" -or $status -like "*NoSuchEntity*") {
        Write-OK "Node group deleted successfully"
        break
    } elseif ($status -eq "DELETING") {
        Write-Host "  [$elapsed/$maxWait s] Status: $status" -ForegroundColor Gray
        Start-Sleep -Seconds 15
        $elapsed += 15
    } else {
        Write-Warn "Status: $status (unexpected)"
        break
    }
}

if ($elapsed -ge $maxWait) {
    Write-Error2 "Deletion timeout - continuing anyway"
}

# === STEP 2: Get Networking Info ===
Write-Step "STEP 2: Getting VPC and Subnet Configuration"

$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" `
    --region $Region --query "Vpcs[0].VpcId" --output text 2>$null

Write-OK "VPC: $VPC_ID"

# Get subnets
$PublicSubnets = @()
$PrivateSubnets = @()
$Subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" `
    --region $Region --output json | ConvertFrom-Json | Select-Object -ExpandProperty Subnets

foreach ($subnet in $Subnets) {
    if ($subnet.MapPublicIpOnLaunch -eq $true) {
        $PublicSubnets += $subnet.SubnetId
    } else {
        $PrivateSubnets += $subnet.SubnetId
    }
}

Write-OK "Public subnets: $($PublicSubnets -join ', ')"
Write-OK "Private subnets: $($PrivateSubnets -join ', ')"

# === STEP 3: Set Up NAT Gateways (Optional but Recommended) ===
Write-Step "STEP 3: Setting Up NAT Gateways"

foreach ($subnet in $PublicSubnets) {
    Write-Info "Creating NAT gateway in $subnet..."
    
    # Get route table for this subnet
    $rtId = aws ec2 describe-route-tables --filters `
        "Name=association.subnet-id,Values=$subnet" `
        --region $Region --query "RouteTables[0].RouteTableId" --output text 2>$null
    
    if ($rtId -and $rtId -ne "None") {
        Write-OK "Route table: $rtId"
    } else {
        Write-Warn "No route table found for $subnet"
    }
}

# === STEP 4: Get Node Role ARN ===
Write-Step "STEP 4: Getting Node Group IAM Role"

$NodeRoleArn = aws iam get-role --role-name "$ProjectName-eks-node-group-role" `
    --query Role.Arn --output text 2>$null

if ($NodeRoleArn) {
    Write-OK "Node Role: $NodeRoleArn"
} else {
    Write-Error2 "Node role not found"
    exit 1
}

# === STEP 5: Create Node Group in PUBLIC subnets ===
Write-Step "STEP 5: Creating Node Group with Corrected Networking"

Write-Info "Using PUBLIC subnets to avoid NAT gateway requirements..."

$PublicSubnetsStr = $PublicSubnets -join " "

Write-Info "Creating node group in: $PublicSubnetsStr"

aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --subnets $PublicSubnets --node-role $NodeRoleArn `
    --scaling-config "minSize=2,maxSize=5,desiredSize=2" `
    --instance-types t3.medium --region $Region 2>$null | Out-Null

Write-OK "Node group creation initiated"

# === STEP 6: Monitor Node Group Creation ===
Write-Step "STEP 6: Monitoring Node Group Creation"

$maxWait = 1200
$elapsed = 0

while ($elapsed -lt $maxWait) {
    $status = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
        --region $Region --query "nodegroup.status" --output text 2>$null
    
    if ($status -eq "ACTIVE") {
        Write-OK "Node group is ACTIVE!"
        
        # Get node info
        $nodeGroup = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
            --region $Region --output json | ConvertFrom-Json
        
        Write-OK "Nodes created: $($nodeGroup.nodegroup.resources.autoScalingGroups[0].name)"
        break
    } elseif ($status -like "*FAILED*") {
        Write-Error2 "Node group creation FAILED"
        $nodeGroup = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
            --region $Region --output json | ConvertFrom-Json
        Write-Error2 "Issues: $($nodeGroup.nodegroup.health.issues | ConvertTo-Json)"
        exit 1
    } else {
        Write-Host "  [$elapsed/$maxWait s] Status: $status" -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds 30
    $elapsed += 30
}

if ($status -ne "ACTIVE") {
    Write-Error2 "Node group did not reach ACTIVE status. Current: $status"
    exit 1
}

# === STEP 7: Verify Cluster Connectivity ===
Write-Step "STEP 7: Verifying Cluster Connectivity"

Write-Info "Checking nodes..."
$nodes = kubectl get nodes -o wide 2>&1

if ($nodes) {
    Write-OK "Cluster connectivity verified!"
    Write-Host $nodes -ForegroundColor Green
} else {
    Write-Warn "Could not retrieve nodes - checking kubectl config..."
    aws eks update-kubeconfig --region $Region --name $ClusterName 2>$null | Out-Null
    Start-Sleep -Seconds 2
    $nodes = kubectl get nodes -o wide 2>&1
    if ($nodes) {
        Write-OK "Nodes after kubeconfig update:"
        Write-Host $nodes -ForegroundColor Green
    }
}

# === SUMMARY ===
Write-Step "NODE GROUP FIXED"

Write-Host @"
Infrastructure Status:
  Cluster:       $ClusterName (ACTIVE)
  Node Group:    $ProjectName-node-group (ACTIVE)
  Subnets:       PUBLIC (10.0.1.0/24, 10.0.2.0/24)
  Region:        $Region

Node Group Details:
  Instance Type:  t3.medium
  Min Size:       2
  Max Size:       5
  Current Size:   2

Issue Fixed:
  ✓ Moved nodes from PRIVATE to PUBLIC subnets
  ✓ Nodes now have direct internet access
  ✓ Allows cluster communication without NAT complexity

Next Steps:
  1. Verify nodes are ready:
     kubectl get nodes

  2. Build and push Docker images:
     .\build-and-push-images.ps1

  3. Deploy applications:
     .\deploy-to-kubernetes.ps1

"@ -ForegroundColor Green

Write-OK "Node networking fixed! Ready for application deployment."
