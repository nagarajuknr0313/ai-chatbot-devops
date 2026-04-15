#############################################################################
# AWS Deployment Script for AI Chatbot DevOps
# Deploys infrastructure, builds images, and launches Kubernetes
# Region: ap-southeast-2 (Sydney)
#############################################################################

param(
    [string]$Action = "deploy-all",  # deploy-all, plan, cleanup
    [string]$Region = "ap-southeast-2",
    [string]$ProjectName = "ai-chatbot",
    [string]$Environment = "production"
)

# Color console output
function Write-Header { Write-Host "`n► $args" -ForegroundColor Cyan -BackgroundColor Black }
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Yellow }

# Get AWS Account ID
function Get-AWSAccountId {
    $accountId = aws sts get-caller-identity --query Account --output text
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get AWS Account ID. Check your credentials."
        exit 1
    }
    return $accountId
}

# Create VPC and Networking
function Deploy-VPC {
    Write-Header "Creating VPC and Networking Infrastructure"
    
    # VPC
    Write-Host "Creating VPC..."
    $vpcJson = aws ec2 create-vpc `
        --cidr-block 10.0.0.0/16 `
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$ProjectName-vpc},{Key=Environment,Value=$Environment}]" `
        --region $Region --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        $vpcId = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" --query "Vpcs[0].VpcId" --output text --region $Region 2>&1
        if ($vpcId -eq "None" -or $LASTEXITCODE -ne 0) {
            Write-Error "Failed to create/find VPC"
            return $null
        }
    }
    else {
        $vpcId = ($vpcJson | ConvertFrom-Json).Vpc.VpcId
    }
    
    Write-Success "VPC Created: $vpcId"
    
    # Enable DNS
    aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames --region $Region 2>&1 | Out-Null
    aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support --region $Region 2>&1 | Out-Null
    
    # Internet Gateway
    Write-Host "Creating Internet Gateway..."
    $igwJson = aws ec2 create-internet-gateway `
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$ProjectName-igw}]" `
        --region $Region --output json 2>&1
    
    $igwId = ($igwJson | ConvertFrom-Json).InternetGateway.InternetGatewayId
    aws ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $igwId --region $Region 2>&1 | Out-Null
    Write-Success "Internet Gateway: $igwId"
    
    # Public Subnets
    Write-Host "Creating Public Subnets..."
    $az1 = (aws ec2 describe-availability-zones --region $Region --query "AvailabilityZones[0].ZoneName" --output text)
    $az2 = (aws ec2 describe-availability-zones --region $Region --query "AvailabilityZones[1].ZoneName" --output text)
    
    $pubSub1 = (aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.1.0/24 --availability-zone $az1 `
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-1}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).Subnet.SubnetId
    
    $pubSub2 = (aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.2.0/24 --availability-zone $az2 `
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-public-2}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).Subnet.SubnetId
    
    Write-Success "Public Subnets: $pubSub1, $pubSub2"
    
    # Enable auto-assign public IPs
    aws ec2 modify-subnet-attribute --subnet-id $pubSub1 --map-public-ip-on-launch --region $Region 2>&1 | Out-Null
    aws ec2 modify-subnet-attribute --subnet-id $pubSub2 --map-public-ip-on-launch --region $Region 2>&1 | Out-Null
    
    # Private Subnets
    Write-Host "Creating Private Subnets..."
    $privSub1 = (aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.10.0/24 --availability-zone $az1 `
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-1}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).Subnet.SubnetId
    
    $privSub2 = (aws ec2 create-subnet --vpc-id $vpcId --cidr-block 10.0.11.0/24 --availability-zone $az2 `
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$ProjectName-private-2}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).Subnet.SubnetId
    
    Write-Success "Private Subnets: $privSub1, $privSub2"
    
    # Elastic IPs for NAT
    Write-Host "Creating Elastic IPs for NAT Gateways..."
    $eipAlloc1 = (aws ec2 allocate-address --domain vpc --region $Region --output json 2>&1 | ConvertFrom-Json).AllocationId
    $eipAlloc2 = (aws ec2 allocate-address --domain vpc --region $Region --output json 2>&1 | ConvertFrom-Json).AllocationId
    
    # NAT Gateways
    Write-Host "Creating NAT Gateways..."
    $nat1 = (aws ec2 create-nat-gateway --subnet-id $pubSub1 --allocation-id $eipAlloc1 `
        --tag-specifications "ResourceType=nat-gateway,Tags=[{Key=Name,Value=$ProjectName-nat-1}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).NatGateway.NatGatewayId
    
    $nat2 = (aws ec2 create-nat-gateway --subnet-id $pubSub2 --allocation-id $eipAlloc2 `
        --tag-specifications "ResourceType=nat-gateway,Tags=[{Key=Name,Value=$ProjectName-nat-2}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).NatGateway.NatGatewayId
    
    Write-Success "NAT Gateways: $nat1, $nat2"
    
    Write-Info "Waiting for NAT Gateways to be available (this may take 1-2 minutes)..."
    Start-Sleep -Seconds 5
    
    # Route Tables
    Write-Host "Creating Route Tables..."
    # Public Route Table
    $pubRtId = (aws ec2 create-route-table --vpc-id $vpcId `
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$ProjectName-public-rt}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).RouteTable.RouteTableId
    
    aws ec2 create-route --route-table-id $pubRtId --destination-cidr-block 0.0.0.0/0 --gateway-id $igwId --region $Region 2>&1 | Out-Null
    aws ec2 associate-route-table --subnet-id $pubSub1 --route-table-id $pubRtId --region $Region 2>&1 | Out-Null
    aws ec2 associate-route-table --subnet-id $pubSub2 --route-table-id $pubRtId --region $Region 2>&1 | Out-Null
    
    Write-Success "Public Route Table: $pubRtId"
    
    # Private Route Tables
    $privRtId1 = (aws ec2 create-route-table --vpc-id $vpcId `
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$ProjectName-private-rt-1}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).RouteTable.RouteTableId
    
    aws ec2 create-route --route-table-id $privRtId1 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat1 --region $Region 2>&1 | Out-Null
    aws ec2 associate-route-table --subnet-id $privSub1 --route-table-id $privRtId1 --region $Region 2>&1 | Out-Null
    
    $privRtId2 = (aws ec2 create-route-table --vpc-id $vpcId `
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$ProjectName-private-rt-2}]" `
        --region $Region --output json 2>&1 | ConvertFrom-Json).RouteTable.RouteTableId
    
    aws ec2 create-route --route-table-id $privRtId2 --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $nat2 --region $Region 2>&1 | Out-Null
    aws ec2 associate-route-table --subnet-id $privSub2 --route-table-id $privRtId2 --region $Region 2>&1 | Out-Null
    
    Write-Success "Private Route Tables: $privRtId1, $privRtId2"
    
    return @{
        VpcId       = $vpcId
        PubSub1     = $pubSub1
        PubSub2     = $pubSub2
        PrivSub1    = $privSub1
        PrivSub2    = $privSub2
        IGWId       = $igwId
        NAT1        = $nat1
        NAT2        = $nat2
    }
}

# Create EKS Cluster
function Deploy-EKS {
    param($NetworkConfig)
    Write-Header "Creating EKS Cluster"
    
    $vpcId = $NetworkConfig.VpcId
    $subnets = @($NetworkConfig.PubSub1, $NetworkConfig.PubSub2, $NetworkConfig.PrivSub1, $NetworkConfig.PrivSub2) -join ','
    
    # Create IAM Role for EKS
    Write-Host "Creating EKS IAM Role..."
    $trustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Service = "eks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        )
    } | ConvertTo-Json -Compress
    
    $roleArn = (aws iam create-role --role-name "$ProjectName-eks-cluster-role" `
        --assume-role-policy-document $trustPolicy --region $Region 2>&1 | ConvertFrom-Json).Role.Arn 2>/dev/null
    
    if ($null -eq $roleArn) {
        $roleArn = (aws iam get-role --role-name "$ProjectName-eks-cluster-role" --region $Region 2>&1 | ConvertFrom-Json).Role.Arn
    }
    
    aws iam attach-role-policy --role-name "$ProjectName-eks-cluster-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" --region $Region 2>&1 | Out-Null
    
    Write-Success "EKS IAM Role: $roleArn"
    
    # Create Security Group
    Write-Host "Creating EKS Security Group..."
    $sgId = (aws ec2 create-security-group --group-name "$ProjectName-eks-cluster-sg" `
        --description "Security group for EKS cluster" --vpc-id $vpcId `
        --region $Region --output json 2>&1 | ConvertFrom-Json).GroupId 2>/dev/null
    
    if ($null -eq $sgId) {
        $sgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=$ProjectName-eks-cluster-sg" `
            --region $Region --query "SecurityGroups[0].GroupId" --output text 2>&1)
    }
    
    aws ec2 authorize-security-group-egress --group-id $sgId --protocol -1 --cidr 0.0.0.0/0 --region $Region 2>&1 | Out-Null
    Write-Success "EKS Security Group: $sgId"
    
    # Create EKS Cluster
    Write-Host "Creating EKS Cluster (this takes 5-10 minutes)..."
    $clusterJson = aws eks create-cluster --name "$ProjectName-cluster" `
        --version 1.28 --role-arn $roleArn `
        --resources-vpc-config "subnetIds=$subnets,securityGroupIds=$sgId" `
        --region $Region --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $clusterName = ($clusterJson | ConvertFrom-Json).cluster.name
        Write-Success "EKS Cluster Created: $clusterName"
    } else {
        # Check if already exists
        $clusterName = (aws eks describe-cluster --name "$ProjectName-cluster" --region $Region `
            --query "cluster.name" --output text 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Write-Info "EKS Cluster already exists: $clusterName"
        } else {
            Write-Error "Failed to create EKS Cluster"
            return $null
        }
    }
    
    return $clusterName
}

# Create Node Group
function Deploy-NodeGroup {
    param($ClusterName, $NetworkConfig)
    Write-Header "Creating Node Group"
    
    # Create IAM Role for Nodes
    Write-Host "Creating Node Group IAM Role..."
    $trustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Service = "ec2.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        )
    } | ConvertTo-Json -Compress
    
    $nodeRoleArn = (aws iam create-role --role-name "$ProjectName-eks-node-group-role" `
        --assume-role-policy-document $trustPolicy --region $Region 2>&1 | ConvertFrom-Json).Role.Arn 2>/dev/null
    
    if ($null -eq $nodeRoleArn) {
        $nodeRoleArn = (aws iam get-role --role-name "$ProjectName-eks-node-group-role" --region $Region 2>&1 | ConvertFrom-Json).Role.Arn
    }
    
    # Attach policies
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" --region $Region 2>&1 | Out-Null
    
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" --region $Region 2>&1 | Out-Null
    
    aws iam attach-role-policy --role-name "$ProjectName-eks-node-group-role" `
        --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" --region $Region 2>&1 | Out-Null
    
    Write-Success "Node IAM Role: $nodeRoleArn"
    
    # Create Node Group
    Write-Host "Creating Node Group (this takes 5-10 minutes)..."
    $ngJson = aws eks create-nodegroup --cluster-name $ClusterName `
        --nodegroup-name "$ProjectName-node-group" --subnets $NetworkConfig.PrivSub1 $NetworkConfig.PrivSub2 `
        --node-role $nodeRoleArn --scaling-config "minSize=2,maxSize=5,desiredSize=2" `
        --instance-types t3.medium --region $Region --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Node Group created successfully"
    } else {
        Write-Info "Checking if Node Group already exists..."
        $existingNg = aws eks describe-nodegroup --cluster-name $ClusterName `
            --nodegroup-name "$ProjectName-node-group" --region $Region 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Node Group already exists"
        } else {
            Write-Error "Failed to create Node Group"
        }
    }
}

# Main Deployment Logic
function Main {
    Write-Header "AWS DEPLOYMENT SCRIPT FOR AI CHATBOT DEVOPS"
    Write-Host "Region: $Region" -ForegroundColor Cyan
    Write-Host "Project: $ProjectName" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host ""
    
    # Verify AWS credentials
    Write-Header "Step 1/5: Verifying AWS Credentials"
    $accountId = Get-AWSAccountId
    Write-Success "AWS Account ID: $accountId"
    
    # Deploy VPC and Networking
    Write-Header "Step 2/5: Deploying VPC and Networking"
    $networkConfig = Deploy-VPC
    
    if ($null -eq $networkConfig) {
        Write-Error "Failed to deploy VPC. Exiting."
        exit 1
    }
    
    # Deploy EKS Cluster
    Write-Header "Step 3/5: Deploying EKS Cluster"
    $clusterName = Deploy-EKS -NetworkConfig $networkConfig
    if ($null -eq $clusterName) {
        Write-Error "Failed to deploy EKS. Exiting."
        exit 1
    }
    
    # Wait for cluster to be active
    Write-Info "Waiting for EKS cluster to be ACTIVE..."
    $maxRetries = 60
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        $status = aws eks describe-cluster --name $clusterName --region $Region --query "cluster.status" --output text 2>&1
        if ($status -eq "ACTIVE") {
            Write-Success "EKS Cluster is ACTIVE"
            break
        }
        Write-Host "  Status: $status... (waiting)" -ForegroundColor Gray
        Start-Sleep -Seconds 10
        $retryCount++
    }
    
    if ($status -ne "ACTIVE") {
        Write-Error "EKS cluster did not reach ACTIVE state"
        exit 1
    }
    
    # Deploy Node Group
    Write-Header "Step 4/5: Deploying Node Group"
    Deploy-NodeGroup -ClusterName $clusterName -NetworkConfig $networkConfig
    
    # Configure kubectl
    Write-Header "Step 5/5: Configuring kubectl"
    Write-Host "Updating kubeconfig..."
    aws eks update-kubeconfig --region $Region --name $clusterName 2>&1 | Out-Null
    
    # Verify cluster access
    Write-Info "Verifying cluster access..."
    kubectl cluster-info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "kubectl configured and cluster is accessible"
    } else {
        Write-Error "Failed to configure kubectl"
    }
    
    # Summary
    Write-Header "DEPLOYMENT COMPLETE"
    Write-Host "AWS Infrastructure Deployed Successfully!`n" -ForegroundColor Green
    
    Write-Host "CLUSTER DETAILS:" -ForegroundColor Cyan
    Write-Host "  Cluster Name: $clusterName"
    Write-Host "  Region: $Region"
    Write-Host "  VPC ID: $($networkConfig.VpcId)"
    Write-Host "  Private Subnets: $($networkConfig.PrivSub1), $($networkConfig.PrivSub2)"
    
    Write-Host "`nNEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. Build and push Docker images: .\build-and-push-images.ps1"
    Write-Host "  2. Deploy to Kubernetes: .\deploy-to-kubernetes.ps1"
    Write-Host "`nMONITORING:" -ForegroundColor Cyan
    Write-Host "  Check node status: kubectl get nodes"
    Write-Host "  Check pods: kubectl get pods -n chatbot"
}

# Execute
Main
