##############################################################################
# AWS EKS Deployment - Final Robust Version
# Creates JSON files separately to avoid escaping issues
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$NodeGroupName = "ai-chatbot-node-group",
    [string]$ProjectName = "ai-chatbot"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Write-OK { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Error2 { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[...] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Step { Write-Host "`n>>> $args" -ForegroundColor Yellow }

Write-Host @"
AWS EKS Deployment - Final Version
Region: $Region | Project: $ProjectName
"@ -ForegroundColor Cyan

# === Helper Functions ===
function Test-AwsCommand { 
    aws sts get-caller-identity --query Account --output text 2>$null
}

function Get-AccountId {
    $id = aws sts get-caller-identity --query Account --output text 2>$null
    if ($id) { return $id }
    Write-Error2 "Cannot get AWS Account ID"
    exit 1
}

# === STEP 1: Verify AWS ===
Write-Step "STEP 1: Verifying AWS Credentials"
$ACCOUNT_ID = Get-AccountId
Write-OK "Account ID: $ACCOUNT_ID"

# === STEP 2: Check VPC ===
Write-Step "STEP 2: Checking VPC"
$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" `
    --region $Region --query "Vpcs[0].VpcId" --output text 2>$null

if ($VPC_ID -eq "None") {
    Write-Error2 "VPC not found. Create it first."
    exit 1
}
Write-OK "VPC: $VPC_ID"

# === STEP 3: Get Subnets ===
Write-Step "STEP 3: Getting Subnets"
$SUBNETS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" `
    --region $Region --query "Subnets[*].SubnetId" --output text 2>$null

if (-not $SUBNETS) {
    Write-Error2 "No subnets found in VPC"
    exit 1
}
Write-OK "Subnets: $SUBNETS"

# === STEP 4: Create IAM Roles ===
Write-Step "STEP 4: Setting Up IAM Roles"

# EKS Cluster Role
Write-Info "Checking EKS Cluster role..."
$ClusterRole = aws iam get-role --role-name "$ProjectName-eks-cluster-role" --query "Role.Arn" --output text 2>$null

if ($ClusterRole -eq "None" -or -not $ClusterRole) {
    Write-Info "Creating EKS Cluster role..."
    
    # Create trust policy file
    $ClusterTrust = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@
    $ClusterTrust | Out-File -FilePath "cluster-trust.json" -Encoding UTF8
    
    # Create role
    aws iam create-role --role-name "$ProjectName-eks-cluster-role" `
        --assume-role-policy-document file://cluster-trust.json 2>$null | Out-Null
    
    # Attach policy
    aws iam attach-role-policy --role-name "$ProjectName-eks-cluster-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" 2>$null | Out-Null
    
    $ClusterRole = aws iam get-role --role-name "$ProjectName-eks-cluster-role" --query "Role.Arn" --output text 2>$null
    Write-OK "EKS Cluster role created: $ClusterRole"
    
    Start-Sleep -Seconds 2
} else {
    Write-OK "EKS Cluster role found: $ClusterRole"
}

# Node Group Role
Write-Info "Checking Node Group role..."
$NodeRole = aws iam get-role --role-name "$ProjectName-eks-node-group-role" --query "Role.Arn" --output text 2>$null

if ($NodeRole -eq "None" -or -not $NodeRole) {
    Write-Info "Creating Node Group role..."
    
    # Create trust policy file
    $NodeTrust = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@
    $NodeTrust | Out-File -FilePath "node-trust.json" -Encoding UTF8
    
    # Create role
    aws iam create-role --role-name "$ProjectName-eks-node-group-role" `
        --assume-role-policy-document file://node-trust.json 2>$null | Out-Null
    
    # Attach policies
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" 2>$null | Out-Null
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" 2>$null | Out-Null
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" 2>$null | Out-Null
    
    $NodeRole = aws iam get-role --role-name "$ProjectName-eks-node-group-role" --query "Role.Arn" --output text 2>$null
    Write-OK "Node Group role created: $NodeRole"
    
    Start-Sleep -Seconds 2
} else {
    Write-OK "Node Group role found: $NodeRole"
}

# Clean up trust files
Remove-Item -Path "cluster-trust.json" -Force 2>$null | Out-Null
Remove-Item -Path "node-trust.json" -Force 2>$null | Out-Null

# === STEP 5: Create/Check EKS Cluster ===
Write-Step "STEP 5: Creating/Checking EKS Cluster"

$ClusterStatus = aws eks describe-cluster --name $ClusterName --region $Region `
    --query "cluster.status" --output text 2>$null

if ($ClusterStatus -eq "ACTIVE") {
    Write-OK "EKS Cluster exists and is ACTIVE"
} elseif ($ClusterStatus -eq "CREATING") {
    Write-Warn "EKS Cluster is currently CREATING"
} elseif ($ClusterStatus -and $ClusterStatus -ne "None") {
    Write-Warn "EKS Cluster exists with status: $ClusterStatus"
} else {
    Write-Info "Creating EKS Cluster..."
    Write-Info "This will take 5-10 minutes. Streaming progress..."
    
    aws eks create-cluster --name $ClusterName --version 1.28 --role-arn $ClusterRole `
        --resources-vpc-config "subnetIds=$SUBNETS" --region $Region 2>$null | Out-Null
    
    Write-OK "Cluster creation initiated"
    Write-Info "Waiting for ACTIVE status..."
    
    $maxWait = 1200
    $elapsed = 0
    
    while ($elapsed -lt $maxWait) {
        $ClusterStatus = aws eks describe-cluster --name $ClusterName --region $Region `
            --query "cluster.status" --output text 2>$null
        
        if ($ClusterStatus -eq "ACTIVE") {
            Write-OK "Cluster is ACTIVE!"
            break
        }
        
        Write-Host "  [$elapsed/$maxWait s] Status: $ClusterStatus" -ForegroundColor Gray
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
}

# === STEP 6: Create/Check Node Group ===
Write-Step "STEP 6: Creating/Checking Node Group"

$NgStatus = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
    --region $Region --query "nodegroup.status" --output text 2>$null

if ($NgStatus -eq "ACTIVE") {
    Write-OK "Node Group exists and is ACTIVE"
} elseif ($NgStatus -eq "CREATING") {
    Write-Warn "Node Group is currently CREATING"
} elseif ($NgStatus -and $NgStatus -ne "None") {
    Write-Warn "Node Group exists with status: $NgStatus"
} else {
    Write-Info "Creating Node Group..."
    Write-Info "This will take 5-15 minutes..."
    
    aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
        --subnets $SUBNETS --node-role $NodeRole `
        --scaling-config "minSize=2,maxSize=5,desiredSize=2" `
        --instance-types t3.medium --region $Region 2>$null | Out-Null
    
    Write-OK "Node Group creation initiated"
    Write-Info "Waiting for ACTIVE status..."
    
    $maxWait = 1200
    $elapsed = 0
    
    while ($elapsed -lt $maxWait) {
        $NgStatus = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
            --region $Region --query "nodegroup.status" --output text 2>$null
        
        if ($NgStatus -eq "ACTIVE") {
            Write-OK "Node Group is ACTIVE!"
            break
        }
        
        Write-Host "  [$elapsed/$maxWait s] Status: $NgStatus" -ForegroundColor Gray
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
}

# === STEP 7: Configure kubectl ===
Write-Step "STEP 7: Configuring kubectl"

Write-Info "Updating kubeconfig..."
aws eks update-kubeconfig --region $Region --name $ClusterName 2>$null | Out-Null

Start-Sleep -Seconds 2

Write-Info "Verifying cluster connection..."
$clusterInfo = kubectl cluster-info 2>$null

if ($clusterInfo) {
    Write-OK "kubectl connected successfully"
    Write-Host $clusterInfo.Split("`n")[0..1] -ForegroundColor Gray
} else {
    Write-Warn "kubectl verification inconclusive"
}

# === STEP 8: Summary ===
Write-Step "DEPLOYMENT SUMMARY"

Write-Host @"
Infrastructure Status:
  Cluster:       $ClusterName
  Region:        $Region
  VPC ID:        $VPC_ID
  Cluster Role:  $ClusterRole
  Node Role:     $NodeRole
  Cluster Status: $ClusterStatus
  Node Status:   $NgStatus

Node Info:
  Type:  t3.medium
  Count: 2 (Min: 2, Max: 5)
  Subnets: $SUBNETS

Next Steps:
  1. Check node readiness:
     kubectl get nodes -o wide

  2. Build Docker images:
     .\build-and-push-images.ps1

  3. Deploy to Kubernetes:
     .\deploy-to-kubernetes.ps1

Commands for Status:
  - Cluster: aws eks describe-cluster --name $ClusterName --region $Region --query cluster.status
  - Nodes:   aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region --query nodegroup.status
  - Kubectl: kubectl get nodes

"@ -ForegroundColor Green

Write-OK "Automated deployment complete!"
Write-Info "Waiting for final status check..."

Start-Sleep -Seconds 5

# Try to show nodes
Write-Info "Current node status:"
kubectl get nodes 2>$null | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

Write-OK "All done!"
