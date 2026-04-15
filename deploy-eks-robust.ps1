##############################################################################
# AWS EKS Deployment - Robust Version with Retry Logic
# Handles timeouts and AWS CLI delays gracefully
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$NodeGroupName = "ai-chatbot-node-group",
    [string]$ProjectName = "ai-chatbot",
    [int]$MaxRetries = 3
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Color functions
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Fail { Write-Host "[FAIL] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Step { Write-Host "`n=== $args ===" -ForegroundColor Yellow }

# Retry logic helper
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return & $ScriptBlock
        } catch {
            if ($attempt -lt $MaxAttempts) {
                Write-Warn "Attempt $attempt failed, retrying in $DelaySeconds seconds..."
                Start-Sleep -Seconds $DelaySeconds
            } else {
                throw
            }
        }
    }
}

# AWS API call helper with timeout handling
function Invoke-AwsCommand {
    param(
        [string]$CommandArgs,
        [string]$Description = "AWS command"
    )
    
    try {
        $result = Invoke-Expression "aws $CommandArgs" 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result
        } else {
            Write-Warn "$Description failed with exit code $LASTEXITCODE"
            return $null
        }
    } catch {
        Write-Warn "$Description error: $_"
        return $null
    }
}

# Main execution
Write-Host -BackgroundColor Black -ForegroundColor Cyan @"

╔═══════════════════════════════════════════════════════════════╗
║           AWS EKS DEPLOYMENT - ROBUST VERSION                ║
║           Region: ap-southeast-2 (Sydney)                    ║
╚═══════════════════════════════════════════════════════════════╝
"@

# Get Account ID
Write-Step "Getting AWS Account ID"
$ACCOUNT_ID = Invoke-AwsCommand "sts get-caller-identity --query Account --output text" "Get Account ID"
if (-not $ACCOUNT_ID) {
    Write-Fail "Cannot retrieve AWS Account ID. Check your credentials."
    exit 1
}
Write-Success "Account ID: $ACCOUNT_ID"

# Check VPC
Write-Step "Checking VPC"
$VPC_ID = Invoke-AwsCommand `
    "ec2 describe-vpcs --filters 'Name=tag:Name,Values=$ProjectName-vpc' --region $Region --query 'Vpcs[0].VpcId' --output text" `
    "Describe VPCs"

if ($VPC_ID -and $VPC_ID -ne "None") {
    Write-Success "VPC found: $VPC_ID"
} else {
    Write-Info "Creating VPC..."
    $VPC_ID = Invoke-AwsCommand `
        "ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=$ProjectName-vpc}]' --region $Region --query 'Vpc.VpcId' --output text" `
        "Create VPC"
    
    if ($VPC_ID) {
        Write-Success "VPC created: $VPC_ID"
        Start-Sleep -Seconds 2
    } else {
        Write-Fail "Failed to create VPC"
        exit 1
    }
}

# Get Availability Zones
Write-Step "Getting Availability Zones"
$AZ1 = Invoke-AwsCommand `
    "ec2 describe-availability-zones --region $Region --query 'AvailabilityZones[0].ZoneName' --output text" `
    "Get AZ1"
$AZ2 = Invoke-AwsCommand `
    "ec2 describe-availability-zones --region $Region --query 'AvailabilityZones[1].ZoneName' --output text" `
    "Get AZ2"

if ($AZ1 -and $AZ2) {
    Write-Success "AZ1: $AZ1, AZ2: $AZ2"
} else {
    Write-Fail "Failed to get availability zones"
    exit 1
}

# Create/Check Subnets
Write-Step "Creating/Checking Subnets"

# Function to create subnet with retry
function Create-OrGetSubnet {
    param([string]$Name, [string]$VpcId, [string]$Cidr, [string]$Az)
    
    # First try to find existing
    $result = Invoke-AwsCommand `
        "ec2 describe-subnets --filters 'Name=tag:Name,Values=$Name' --region $Region --query 'Subnets[0].SubnetId' --output text" `
        "Check subnet $Name"
    
    if ($result -and $result -ne "None") {
        Write-Info "Subnet found: $Name = $result"
        return $result
    }
    
    # Create new
    Write-Info "Creating subnet: $Name ($Cidr)..."
    $result = Invoke-AwsCommand `
        "ec2 create-subnet --vpc-id $VpcId --cidr-block $Cidr --availability-zone $Az --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=$Name}]' --region $Region --query 'Subnet.SubnetId' --output text" `
        "Create subnet $Name"
    
    if ($result) {
        Write-Success "Subnet created: $Name = $result"
        Start-Sleep -Seconds 1
        return $result
    } else {
        Write-Fail "Failed to create subnet: $Name"
        return $null
    }
}

$PUB_SUB1 = Create-OrGetSubnet "$ProjectName-public-1" $VPC_ID "10.0.1.0/24" $AZ1
$PUB_SUB2 = Create-OrGetSubnet "$ProjectName-public-2" $VPC_ID "10.0.2.0/24" $AZ2
$PRIV_SUB1 = Create-OrGetSubnet "$ProjectName-private-1" $VPC_ID "10.0.10.0/24" $AZ1
$PRIV_SUB2 = Create-OrGetSubnet "$ProjectName-private-2" $VPC_ID "10.0.11.0/24" $AZ2

if (-not ($PUB_SUB1 -and $PUB_SUB2 -and $PRIV_SUB1 -and $PRIV_SUB2)) {
    Write-Fail "Failed to create all subnets"
    exit 1
}

Write-Success "All subnets ready"

# Enable auto-assign public IPs
Write-Info "Enabling auto-assign public IPs..."
Invoke-AwsCommand "ec2 modify-subnet-attribute --subnet-id $PUB_SUB1 --map-public-ip-on-launch --region $Region" "Enable public IPs on $PUB_SUB1" | Out-Null
Invoke-AwsCommand "ec2 modify-subnet-attribute --subnet-id $PUB_SUB2 --map-public-ip-on-launch --region $Region" "Enable public IPs on $PUB_SUB2" | Out-Null

# Create Internet Gateway
Write-Step "Creating/Checking Internet Gateway"
$IGW_ID = Invoke-AwsCommand `
    "ec2 describe-internet-gateways --filters 'Name=tag:Name,Values=$ProjectName-igw' --region $Region --query 'InternetGateways[0].InternetGatewayId' --output text" `
    "Describe IGW"

if (-not $IGW_ID -or $IGW_ID -eq "None") {
    Write-Info "Creating Internet Gateway..."
    $IGW_ID = Invoke-AwsCommand `
        "ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=$ProjectName-igw}]' --region $Region --query 'InternetGateway.InternetGatewayId' --output text" `
        "Create IGW"
    
    if ($IGW_ID) {
        Write-Success "IGW created: $IGW_ID"
        
        # Attach to VPC
        Invoke-AwsCommand "ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $Region" "Attach IGW" | Out-Null
        Start-Sleep -Seconds 1
    }
} else {
    Write-Success "IGW found: $IGW_ID"
}

# Create EKS Cluster IAM Role
Write-Step "Setting Up EKS Cluster IAM Role"
$CLUSTER_ROLE_ARN = Invoke-AwsCommand "iam get-role --role-name '$ProjectName-eks-cluster-role' --query 'Role.Arn' --output text" "Get cluster role"

if (-not $CLUSTER_ROLE_ARN -or $CLUSTER_ROLE_ARN -like "*NoSuchEntity*") {
    Write-Info "Creating IAM role for EKS cluster..."
    
    $TRUST_POLICY = @{
        Version = "2012-10-17"
        Statement = @(@{
            Effect = "Allow"
            Principal = @{ Service = "eks.amazonaws.com" }
            Action = "sts:AssumeRole"
        })
    } | ConvertTo-Json -Compress
    
    $CLUSTER_ROLE_ARN = Invoke-AwsCommand `
        "iam create-role --role-name '$ProjectName-eks-cluster-role' --assume-role-policy-document '$TRUST_POLICY' --query 'Role.Arn' --output text" `
        "Create cluster role"
    
    if ($CLUSTER_ROLE_ARN) {
        Write-Success "Cluster role created: $CLUSTER_ROLE_ARN"
        
        # Attach policy
        Invoke-AwsCommand `
            "iam attach-role-policy --role-name '$ProjectName-eks-cluster-role' --policy-arn 'arn:aws:iam::aws:policy/AmazonEKSClusterPolicy'" `
            "Attach cluster policy" | Out-Null
        
        Start-Sleep -Seconds 2
    } else {
        Write-Fail "Failed to create cluster role"
        exit 1
    }
} else {
    Write-Success "Cluster role found: $CLUSTER_ROLE_ARN"
}

# Create EKS Cluster
Write-Step "Creating/Checking EKS Cluster"
$CLUSTER_STATUS = Invoke-AwsCommand `
    "eks describe-cluster --name $ClusterName --region $Region --query 'cluster.status' --output text" `
    "Describe EKS cluster"

if ($CLUSTER_STATUS -and $CLUSTER_STATUS -ne "None" -and $CLUSTER_STATUS -ne "DELETING") {
    Write-Success "EKS Cluster exists (Status: $CLUSTER_STATUS)"
} else {
    Write-Info "Creating EKS Cluster (takes 5-10 minutes)..."
    Write-Info "This may take a while. Waiting for cluster to be ACTIVE..."
    
    $SUBNETS = "$PUB_SUB1 $PUB_SUB2 $PRIV_SUB1 $PRIV_SUB2"
    
    Invoke-AwsCommand `
        "eks create-cluster --name $ClusterName --version 1.28 --role-arn $CLUSTER_ROLE_ARN --resources-vpc-config 'subnetIds=$SUBNETS' --region $Region" `
        "Create EKS cluster" | Out-Null
    
    Write-Info "Cluster creation initiated. Checking status..."
    
    # Wait for cluster to be ACTIVE with timeout
    $timeout = 1200  # 20 minutes
    $elapsed = 0
    
    while ($elapsed -lt $timeout) {
        $CLUSTER_STATUS = Invoke-AwsCommand `
            "eks describe-cluster --name $ClusterName --region $Region --query 'cluster.status' --output text" `
            "Check cluster status"
        
        if ($CLUSTER_STATUS -eq "ACTIVE") {
            Write-Success "Cluster is ACTIVE!"
            break
        }
        
        Write-Host "  [$($elapsed)s/$($timeout)s] Status: $CLUSTER_STATUS" -ForegroundColor Gray
        
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    if ($CLUSTER_STATUS -ne "ACTIVE") {
        Write-Fail "Cluster failed to reach ACTIVE status (current: $CLUSTER_STATUS)"
        exit 1
    }
}

# Create Node Group IAM Role
Write-Step "Setting Up Node Group IAM Role"
$NODE_ROLE_ARN = Invoke-AwsCommand "iam get-role --role-name '$ProjectName-eks-node-group-role' --query 'Role.Arn' --output text" "Get node role"

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
    
    $NODE_ROLE_ARN = Invoke-AwsCommand `
        "iam create-role --role-name '$ProjectName-eks-node-group-role' --assume-role-policy-document '$NODE_TRUST_POLICY' --query 'Role.Arn' --output text" `
        "Create node role"
    
    if ($NODE_ROLE_ARN) {
        Write-Success "Node role created: $NODE_ROLE_ARN"
        
        # Attach policies
        Invoke-AwsCommand `
            "iam attach-role-policy --role-name '$ProjectName-eks-node-group-role' --policy-arn 'arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy'" `
            "Attach worker policy" | Out-Null
        Invoke-AwsCommand `
            "iam attach-role-policy --role-name '$ProjectName-eks-node-group-role' --policy-arn 'arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy'" `
            "Attach CNI policy" | Out-Null
        Invoke-AwsCommand `
            "iam attach-role-policy --role-name '$ProjectName-eks-node-group-role' --policy-arn 'arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly'" `
            "Attach ECR policy" | Out-Null
        
        Start-Sleep -Seconds 2
    } else {
        Write-Fail "Failed to create node role"
        exit 1
    }
} else {
    Write-Success "Node role found: $NODE_ROLE_ARN"
}

# Create Node Group
Write-Step "Creating/Checking Node Group"
$NG_STATUS = Invoke-AwsCommand `
    "eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region --query 'nodegroup.status' --output text" `
    "Describe node group"

if ($NG_STATUS -and $NG_STATUS -ne "None" -and $NG_STATUS -ne "DELETING") {
    Write-Success "Node Group exists (Status: $NG_STATUS)"
} else {
    Write-Info "Creating Node Group (takes 5-15 minutes)..."
    
    Invoke-AwsCommand `
        "eks create-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --subnets $PRIV_SUB1 $PRIV_SUB2 --node-role $NODE_ROLE_ARN --scaling-config 'minSize=2,maxSize=5,desiredSize=2' --instance-types t3.medium --region $Region" `
        "Create node group" | Out-Null
    
    Write-Info "Node Group creation initiated. Waiting for nodes to be ACTIVE..."
    
    # Wait for node group to be ACTIVE
    $timeout = 1200  # 20 minutes
    $elapsed = 0
    
    while ($elapsed -lt $timeout) {
        $NG_STATUS = Invoke-AwsCommand `
            "eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region --query 'nodegroup.status' --output text" `
            "Check node group status"
        
        if ($NG_STATUS -eq "ACTIVE") {
            Write-Success "Node Group is ACTIVE!"
            break
        }
        
        Write-Host "  [$($elapsed)s/$($timeout)s] Status: $NG_STATUS" -ForegroundColor Gray
        
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    if ($NG_STATUS -ne "ACTIVE") {
        Write-Warn "Node Group status: $NG_STATUS (may take additional time)"
    }
}

# Configure kubectl
Write-Step "Configuring kubectl"
Write-Info "Updating kubeconfig..."
Invoke-AwsCommand "eks update-kubeconfig --region $Region --name $ClusterName" "Update kubeconfig" | Out-Null

Start-Sleep -Seconds 2

Write-Info "Verifying cluster access..."
$clusterInfo = Invoke-AwsCommand "cluster-info" "Get kubectl cluster info"

if ($clusterInfo) {
    Write-Success "kubectl configured successfully"
} else {
    Write-Warn "kubectl verification inconclusive, but configuration was attempted"
}

# Summary
Write-Step "DEPLOYMENT SUMMARY"
Write-Host @"
Configuration Summary:
  • Cluster Name: $ClusterName
  • Region: $Region
  • VPC ID: $VPC_ID
  • Public Subnets: $PUB_SUB1, $PUB_SUB2
  • Private Subnets: $PRIV_SUB1, $PRIV_SUB2
  • Node Group: $NodeGroupName (2x t3.medium)
  • Node Group Status: $NG_STATUS
  • Cluster Status: $CLUSTER_STATUS

Next Steps:
  1. Verify nodes are ready: kubectl get nodes -o wide
  2. Build Docker images: .\build-and-push-images.ps1
  3. Deploy to Kubernetes: .\deploy-to-kubernetes.ps1

To check status anytime:
  aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.status'
  aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region --query 'nodegroup.status'
  kubectl get nodes

"@ -ForegroundColor Green

# Try to show nodes if cluster is ready
Write-Info "Attempting to display current node status..."
$nodes = kubectl get nodes --no-headers 2>&1
if ($nodes -and $nodes -notlike "*error*" -and $nodes -notlike "*Unable*") {
    Write-Host "Current Nodes:" -ForegroundColor Cyan
    Write-Host $nodes
} else {
    Write-Warn "Nodes not yet available (cluster may still be initializing)"
}

Write-Success "Deployment script completed!"
Write-Info "Cluster and nodes may take additional time to fully initialize."
Write-Info "Check status with: kubectl get nodes --watch"
