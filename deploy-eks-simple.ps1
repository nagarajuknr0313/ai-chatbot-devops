##############################################################################
# Simple AWS EKS Deployment - Step by Step
# A more reliable approach with better error handling and monitoring
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$NodeGroupName = "ai-chatbot-node-group",
    [string]$ProjectName = "ai-chatbot"
)

$ErrorActionPreference = "Continue"

function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Error2 { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Step { Write-Host "`n>>> $args" -ForegroundColor Yellow }

# AWS Account ID
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text 2>$null
if (-not $ACCOUNT_ID) {
    Write-Error2 "Cannot get AWS Account ID. Check credentials."
    exit 1
}

Write-Host "AWS EKS Deployment - ap-southeast-2" -ForegroundColor Cyan -BackgroundColor Black
Write-Host "Account: $ACCOUNT_ID | Project: $ProjectName`n" -ForegroundColor Gray

# ==============================================================================
# PART 1: Check/Create VPC
# ==============================================================================
Write-Step "PART 1: Checking VPC"

$VPC_ID = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" `
    --region $Region --query "Vpcs[0].VpcId" --output text 2>$null

if ($VPC_ID -and $VPC_ID -ne "None") {
    Write-Success "VPC found: $VPC_ID"
} else {
    Write-Info "Creating VPC (10.0.0.0/16)..."
    $VPC_ID = aws ec2 create-vpc --cidr-block "10.0.0.0/16" `
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$ProjectName-vpc}]" `
        --region $Region --query "Vpc.VpcId" --output text 2>$null
    
    if ($VPC_ID) {
        Write-Success "VPC created: $VPC_ID"
        
        # Enable DNS
        aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $Region 2>$null
        aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support --region $Region 2>$null
        Write-Info "DNS enabled"
    } else {
        Write-Error2 "Failed to create VPC"
        exit 1
    }
}

# ==============================================================================
# PART 2: Check/Create Subnets
# ==============================================================================
Write-Step "PART 2: Checking Subnets"

$PUB_SUB1 = aws ec2 describe-subnets --filters "Name=tag:Name,Values=$ProjectName-public-1" `
    --region $Region --query "Subnets[0].SubnetId" --output text 2>$null

if (-not $PUB_SUB1 -or $PUB_SUB1 -eq "None") {
    Write-Info "Creating public subnets..."
    
    $AZ1 = aws ec2 describe-availability-zones --region $Region `
        --query "AvailabilityZones[0].ZoneName" --output text 2>$null
    $AZ2 = aws ec2 describe-availability-zones --region $Region `
        --query "AvailabilityZones[1].ZoneName" --output text 2>$null
    
    # Public subnets
    $PUB_SUB1 = aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" `
        --availability-zone $AZ1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-1}]" `
        --region $Region --query "Subnet.SubnetId" --output text 2>$null
    
    $PUB_SUB2 = aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.2.0/24" `
        --availability-zone $AZ2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-2}]" `
        --region $Region --query "Subnet.SubnetId" --output text 2>$null
    
    # Private subnets
    $PRIV_SUB1 = aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.10.0/24" `
        --availability-zone $AZ1 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-1}]" `
        --region $Region --query "Subnet.SubnetId" --output text 2>$null
    
    $PRIV_SUB2 = aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.11.0/24" `
        --availability-zone $AZ2 --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-2}]" `
        --region $Region --query "Subnet.SubnetId" --output text 2>$null
    
    # Enable auto-assign public IPs
    aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB1 --map-public-ip-on-launch --region $Region 2>$null
    aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB2 --map-public-ip-on-launch --region $Region 2>$null
    
    Write-Success "Subnets created"
} else {
    $PUB_SUB2 = aws ec2 describe-subnets --filters "Name=tag:Name,Values=$ProjectName-public-2" `
        --region $Region --query "Subnets[0].SubnetId" --output text 2>$null
    $PRIV_SUB1 = aws ec2 describe-subnets --filters "Name=tag:Name,Values=$ProjectName-private-1" `
        --region $Region --query "Subnets[0].SubnetId" --output text 2>$null
    $PRIV_SUB2 = aws ec2 describe-subnets --filters "Name=tag:Name,Values=$ProjectName-private-2" `
        --region $Region --query "Subnets[0].SubnetId" --output text 2>$null
    
    Write-Success "Subnets found"
}

Write-Info "Public:  $PUB_SUB1, $PUB_SUB2"
Write-Info "Private: $PRIV_SUB1, $PRIV_SUB2"

# ==============================================================================
# PART 3: Check/Create Internet Gateway
# ==============================================================================
Write-Step "PART 3: Checking Internet Gateway"

$IGW_ID = aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=$ProjectName-igw" `
    --region $Region --query "InternetGateways[0].InternetGatewayId" --output text 2>$null

if (-not $IGW_ID -or $IGW_ID -eq "None") {
    Write-Info "Creating Internet Gateway..."
    $IGW_ID = aws ec2 create-internet-gateway `
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$ProjectName-igw}]" `
        --region $Region --query "InternetGateway.InternetGatewayId" --output text 2>$null
    
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $Region 2>$null
    Write-Success "Internet Gateway created: $IGW_ID"
} else {
    Write-Success "Internet Gateway found: $IGW_ID"
}

# ==============================================================================
# PART 4: Check/Create EKS Cluster IAM Role
# ==============================================================================
Write-Step "PART 4: Checking EKS Cluster IAM Role"

$ROLE_ARN = aws iam get-role --role-name "$ProjectName-eks-cluster-role" --query "Role.Arn" --output text 2>$null

if (-not $ROLE_ARN -or $ROLE_ARN -like "*NoSuchEntity*") {
    Write-Info "Creating IAM role for EKS cluster..."
    
    $TRUST_POLICY = @{
        Version = "2012-10-17"
        Statement = @(@{
            Effect = "Allow"
            Principal = @{ Service = "eks.amazonaws.com" }
            Action = "sts:AssumeRole"
        })
    } | ConvertTo-Json -Compress
    
    $ROLE_ARN = aws iam create-role --role-name "$ProjectName-eks-cluster-role" `
        --assume-role-policy-document $TRUST_POLICY --query "Role.Arn" --output text 2>$null
    
    aws iam attach-role-policy --role-name "$ProjectName-eks-cluster-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" 2>$null
    
    Write-Success "IAM role created: $ROLE_ARN"
} else {
    Write-Success "IAM role found: $ROLE_ARN"
}

# ==============================================================================
# PART 5: Check/Create EKS Cluster
# ==============================================================================
Write-Step "PART 5: Checking EKS Cluster"

$CLUSTER_STATUS = aws eks describe-cluster --name $ClusterName --region $Region `
    --query "cluster.status" --output text 2>$null

if ($CLUSTER_STATUS -and $CLUSTER_STATUS -ne "None" -and $CLUSTER_STATUS -ne "DELETING") {
    Write-Success "EKS Cluster found: $ClusterName (Status: $CLUSTER_STATUS)"
} else {
    Write-Info "Creating EKS Cluster $ClusterName (this takes 5-10 minutes)..."
    Write-Info "Waiting... check progress in another terminal with:"
    Write-Info "  aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.status'"
    
    $SUBNETS = "$PUB_SUB1,$PUB_SUB2,$PRIV_SUB1,$PRIV_SUB2"
    
    aws eks create-cluster --name $ClusterName --version 1.28 --role-arn $ROLE_ARN `
        --resources-vpc-config "subnetIds=$SUBNETS" --region $Region --output text 2>$null
    
    Write-Success "Cluster creation initiated"
    
    # Wait for cluster to be ACTIVE
    Write-Info "Waiting for cluster to reach ACTIVE status (this may take 10-15 minutes)..."
    $maxWait = 1200  # 20 minutes
    $elapsed = 0
    
    while ($elapsed -lt $maxWait) {
        $CLUSTER_STATUS = aws eks describe-cluster --name $ClusterName --region $Region `
            --query "cluster.status" --output text 2>$null
        
        if ($CLUSTER_STATUS -eq "ACTIVE") {
            Write-Success "EKS Cluster is ACTIVE!"
            break
        }
        
        Write-Host "  [$elapsed/$maxWait s] Status: $CLUSTER_STATUS" -ForegroundColor Gray
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    if ($CLUSTER_STATUS -ne "ACTIVE") {
        Write-Error2 "Cluster did not reach ACTIVE status. Current status: $CLUSTER_STATUS"
        exit 1
    }
}

# ==============================================================================
# PART 6: Check/Create Node Group IAM Role
# ==============================================================================
Write-Step "PART 6: Checking Node Group IAM Role"

$NODE_ROLE_ARN = aws iam get-role --role-name "$ProjectName-eks-node-group-role" --query "Role.Arn" --output text 2>$null

if (-not $NODE_ROLE_ARN -or $NODE_ROLE_ARN -like "*NoSuchEntity*") {
    Write-Info "Creating IAM role for Node Group..."
    
    $NODE_TRUST_POLICY = @{
        Version = "2012-10-17"
        Statement = @(@{
            Effect = "Allow"
            Principal = @{ Service = "ec2.amazonaws.com" }
            Action = "sts:AssumeRole"
        })
    } | ConvertTo-Json -Compress
    
    $NODE_ROLE_ARN = aws iam create-role --role-name "$ProjectName-eks-node-group-role" `
        --assume-role-policy-document $NODE_TRUST_POLICY --query "Role.Arn" --output text 2>$null
    
    # Attach policies
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" 2>$null
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" 2>$null
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" 2>$null
    
    Write-Success "Node IAM role created: $NODE_ROLE_ARN"
} else {
    Write-Success "Node IAM role found: $NODE_ROLE_ARN"
}

# ==============================================================================
# PART 7: Check/Create Node Group
# ==============================================================================
Write-Step "PART 7: Checking Node Group"

$NG_STATUS = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
    --region $Region --query "nodegroup.status" --output text 2>$null

if ($NG_STATUS -and $NG_STATUS -ne "None" -and $NG_STATUS -ne "DELETING") {
    Write-Success "Node Group found: $NodeGroupName (Status: $NG_STATUS)"
} else {
    Write-Info "Creating Node Group (this takes 5-15 minutes)..."
    
    aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
        --subnets $PRIV_SUB1 $PRIV_SUB2 --node-role $NODE_ROLE_ARN `
        --scaling-config "minSize=2,maxSize=5,desiredSize=2" `
        --instance-types t3.medium --region $Region --output text 2>$null
    
    Write-Success "Node Group creation initiated"
    
    # Wait for node group to be ACTIVE
    Write-Info "Waiting for nodes to be ACTIVE..."
    $maxWait = 1200  # 20 minutes
    $elapsed = 0
    
    while ($elapsed -lt $maxWait) {
        $NG_STATUS = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName `
            --region $Region --query "nodegroup.status" --output text 2>$null
        
        if ($NG_STATUS -eq "ACTIVE") {
            Write-Success "Node Group is ACTIVE!"
            break
        }
        
        Write-Host "  [$elapsed/$maxWait s] Status: $NG_STATUS" -ForegroundColor Gray
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    if ($NG_STATUS -ne "ACTIVE") {
        Write-Error2 "Node Group did not reach ACTIVE status. Current status: $NG_STATUS"
        exit 1
    }
}

# ==============================================================================
# PART 8: Configure kubectl
# ==============================================================================
Write-Step "PART 8: Configuring kubectl"

Write-Info "Updating kubeconfig..."
aws eks update-kubeconfig --region $Region --name $ClusterName 2>&1 | Out-Null

Write-Info "Verifying cluster access..."
$clusterInfo = kubectl cluster-info 2>&1 | Select-Object -First 1

if ($clusterInfo -like "*control*" -or $clusterInfo -like "*kubernetes*") {
    Write-Success "kubectl configured successfully"
} else {
    Write-Error2 "kubectl configuration failed"
    exit 1
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Step "DEPLOYMENT COMPLETE"

Write-Host @"
SUCCESS! AWS EKS infrastructure is ready.

SUMMARY:
  Cluster:    $ClusterName
  Region:     $Region
  VPC ID:     $VPC_ID
  Subnets:    $PUB_SUB1, $PUB_SUB2 (public)
              $PRIV_SUB1, $PRIV_SUB2 (private)
  Nodes:      2x t3.medium

NEXT STEPS:
  1. Verify nodes: kubectl get nodes -o wide
  2. Create ECR repos: aws ecr create-repository --repository-name ai-chatbot/backend
  3. Build & push images: .\build-and-push-images.ps1
  4. Deploy to K8s: .\deploy-to-kubernetes.ps1

"@ -ForegroundColor Green

# Display nodes
Write-Info "Current node status:"
kubectl get nodes -o wide

Write-Success "All done!"
