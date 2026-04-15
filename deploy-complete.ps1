##############################################################################
# AWS EKS Deployment - Complete Flow
# 1. Creates Node Group IAM role
# 2. Deploys EKS Cluster & Node Group using existing Cluster Role
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

Write-Host "AWS EKS Complete Deployment`nRegion: $Region`n" -ForegroundColor Cyan

# === STEP 1: Get Cluster Role ===
Write-Step "STEP 1: Getting Cluster IAM Role"

$ClusterRoleArn = aws iam get-role --role-name "AmazonEKSAutoClusterRole" `
    --query Role.Arn --output text 2>$null

if (-not $ClusterRoleArn -or $ClusterRoleArn -like "*NoSuchEntity*") {
    Write-Error2 "Cluster role 'AmazonEKSAutoClusterRole' not found"
    exit 1
}
Write-OK "Cluster Role: $ClusterRoleArn"

# === STEP 2: Create Node Role ===
Write-Step "STEP 2: Creating Node Group IAM Role"

$NodeRoleArn = aws iam get-role --role-name "$ProjectName-eks-node-group-role" `
    --query Role.Arn --output text 2>$null

if ($NodeRoleArn -and $NodeRoleArn -notlike "*NoSuchEntity*") {
    Write-OK "Node Role already exists: $NodeRoleArn"
} else {
    Write-Info "Creating node group role..."
    
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
    $NodeTrust | Out-File -FilePath node-trust.json -Encoding UTF8 -Force
    
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
    
    # Get ARN
    $NodeRoleArn = aws iam get-role --role-name "$ProjectName-eks-node-group-role" `
        --query Role.Arn --output text 2>$null
    
    Write-OK "Node Role created: $NodeRoleArn"
    
    # Clean up
    Remove-Item -Path "node-trust.json" -Force 2>$null | Out-Null
    
    Start-Sleep -Seconds 2
}

# === STEP 3: Get VPC & Subnets ===
Write-Step "STEP 3: Getting VPC and Subnets"

$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" `
    --region $Region --query "Vpcs[0].VpcId" --output text 2>$null

if ($VPC_ID -eq "None") {
    Write-Error2 "VPC not found"
    exit 1
}
Write-OK "VPC: $VPC_ID"

$SUBNETS = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" `
    --region $Region --query "Subnets[*].SubnetId" --output text 2>$null

if (-not $SUBNETS) {
    Write-Error2 "No subnets found"
    exit 1
}
Write-OK "Subnets: $SUBNETS"

# === STEP 4: Create EKS Cluster ===
Write-Step "STEP 4: Creating EKS Cluster"

$ClusterStatus = aws eks describe-cluster --name $ClusterName --region $Region `
    --query "cluster.status" --output text 2>$null

if ($ClusterStatus -eq "ACTIVE") {
    Write-OK "Cluster is already ACTIVE"
} elseif ($ClusterStatus -and $ClusterStatus -ne "None") {
    Write-Warn "Cluster exists with status: $ClusterStatus"
} else {
    Write-Info "Creating EKS Cluster (takes 5-10 minutes)..."
    
    aws eks create-cluster --name $ClusterName --version 1.28 --role-arn $ClusterRoleArn `
        --resources-vpc-config "subnetIds=$SUBNETS" --region $Region 2>$null | Out-Null
    
    Write-OK "Cluster creation initiated"
    Write-Info "Streaming progress..."
    
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
    
    if ($ClusterStatus -ne "ACTIVE") {
        Write-Error2 "Cluster did not reach ACTIVE status. Current: $ClusterStatus"
        exit 1
    }
}

# === STEP 5: Create Node Group ===
Write-Step "STEP 5: Creating Node Group"

$NgStatus = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
    --region $Region --query "nodegroup.status" --output text 2>$null

if ($NgStatus -eq "ACTIVE") {
    Write-OK "Node Group is already ACTIVE"
} elseif ($NgStatus -and $NgStatus -ne "None") {
    Write-Warn "Node Group exists with status: $NgStatus"
} else {
    Write-Info "Creating Node Group (takes 5-15 minutes)..."
    
    aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
        --subnets $SUBNETS --node-role $NodeRoleArn `
        --scaling-config "minSize=2,maxSize=5,desiredSize=2" `
        --instance-types t3.medium --region $Region 2>$null | Out-Null
    
    Write-OK "Node Group creation initiated"
    Write-Info "Streaming progress..."
    
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
    
    if ($NgStatus -ne "ACTIVE") {
        Write-Error2 "Node Group did not reach ACTIVE status. Current: $NgStatus"
        exit 1
    }
}

# === STEP 6: Configure kubectl ===
Write-Step "STEP 6: Configuring kubectl"

Write-Info "Updating kubeconfig..."
aws eks update-kubeconfig --region $Region --name $ClusterName 2>$null | Out-Null

Start-Sleep -Seconds 2

Write-Info "Verifying cluster connection..."
$clusterInfo = kubectl cluster-info 2>$null

if ($clusterInfo) {
    Write-OK "kubectl configured successfully"
}

# === SUMMARY ===
Write-Step "DEPLOYMENT COMPLETE"

Write-Host @"
Infrastructure Status:
  Cluster:       $ClusterName (ACTIVE)
  Node Group:    $NodeGroupName (ACTIVE)
  Region:        $Region
  VPC ID:        $VPC_ID

IAM Roles:
  Cluster Role:  AmazonEKSAutoClusterRole
  Node Role:     $ProjectName-eks-node-group-role

Next Steps:
  1. Verify nodes ready:
     kubectl get nodes -o wide

  2. Build Docker images:
     .\build-and-push-images.ps1

  3. Deploy to Kubernetes:
     .\deploy-to-kubernetes.ps1

Useful Commands:
  - Node status:   kubectl get nodes
  - Pod status:    kubectl get pods -n chatbot
  - Cluster info:  kubectl cluster-info

"@ -ForegroundColor Green

Write-OK "Infrastructure ready! You can now proceed with application deployment."
