##############################################################################
# Validate IAM Roles and Deployment Prerequisites
##############################################################################

Write-Host "AWS EKS Deployment Prerequisites Check`n" -ForegroundColor Cyan

$Region = "ap-southeast-2"
$ProjectName = "ai-chatbot"

# Check AWS Credentials
Write-Host "1. Checking AWS Credentials..." -ForegroundColor Yellow
$AccountId = aws sts get-caller-identity --query Account --output text 2>$null
if ($AccountId) {
    Write-Host "   [OK] Account: $AccountId" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Cannot connect to AWS" -ForegroundColor Red
    exit 1
}

# Check VPC
Write-Host "2. Checking VPC..." -ForegroundColor Yellow
$VpcId = aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$ProjectName-vpc" `
    --region $Region --query "Vpcs[0].VpcId" --output text 2>$null
if ($VpcId -and $VpcId -ne "None") {
    Write-Host "   [OK] VPC: $VpcId" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] VPC not found" -ForegroundColor Red
}

# Check Subnets
Write-Host "3. Checking Subnets..." -ForegroundColor Yellow
$SubnetsCount = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" `
    --region $Region --query "length(Subnets)" --output text 2>$null
if ($SubnetsCount -ge 4) {
    Write-Host "   [OK] Found $SubnetsCount subnets" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Only found $SubnetsCount subnets (need 4)" -ForegroundColor Red
}

# Check Cluster Role
Write-Host "4. Checking Cluster IAM Role..." -ForegroundColor Yellow
$ClusterRole = aws iam get-role --role-name "AmazonEKSAutoClusterRole" --query Role.Arn --output text 2>$null
if ($ClusterRole -and $ClusterRole -notlike "*NoSuchEntity*") {
    Write-Host "   [OK] Cluster Role: $ClusterRole" -ForegroundColor Green
} else {
    Write-Host "   [MISSING] AmazonEKSAutoClusterRole not found" -ForegroundColor Yellow
    Write-Host "   Need to create IAM role with trust: EKS, Policies: AmazonEKSClusterPolicy" -ForegroundColor Gray
}

# Check Node Role
Write-Host "5. Checking Node Group IAM Role..." -ForegroundColor Yellow
$NodeRole = aws iam get-role --role-name "ai-chatbot-eks-node-group-role" --query Role.Arn --output text 2>$null
if ($NodeRole -and $NodeRole -notlike "*NoSuchEntity*") {
    Write-Host "   [OK] Node Role: $NodeRole" -ForegroundColor Green
    
    # Check attached policies
    $policies = aws iam list-attached-role-policies --role-name "ai-chatbot-eks-node-group-role" `
        --query "AttachedPolicies[*].PolicyName" --output text 2>$null
    if ($policies) {
        Write-Host "   [OK] Policies attached:" -ForegroundColor Green
        $policies.Split() | ForEach-Object { Write-Host "        - $_" -ForegroundColor Gray }
    }
} else {
    Write-Host "   [MISSING] ai-chatbot-eks-node-group-role not found" -ForegroundColor Yellow
    Write-Host "   Need to create IAM role with trust: EC2, Policies:" -ForegroundColor Gray
    Write-Host "        - AmazonEKSWorkerNodePolicy" -ForegroundColor Gray
    Write-Host "        - AmazonEKS_CNI_Policy" -ForegroundColor Gray
    Write-Host "        - AmazonEC2ContainerRegistryReadOnly" -ForegroundColor Gray
}

# Check EKS Cluster
Write-Host "6. Checking EKS Cluster..." -ForegroundColor Yellow
$ClusterStatus = aws eks describe-cluster --name "ai-chatbot-cluster" --region $Region `
    --query "cluster.status" --output text 2>$null
if ($ClusterStatus -and $ClusterStatus -ne "None") {
    Write-Host "   [OK] Cluster Status: $ClusterStatus" -ForegroundColor Green
} else {
    Write-Host "   [NOT CREATED] EKS Cluster does not exist yet" -ForegroundColor Yellow
}

# Check Node Group
Write-Host "7. Checking Node Group..." -ForegroundColor Yellow
$NgStatus = aws eks describe-nodegroup --cluster-name "ai-chatbot-cluster" `
    --nodegroup-name "ai-chatbot-node-group" --region $Region `
    --query "nodegroup.status" --output text 2>$null
if ($NgStatus -and $NgStatus -ne "None") {
    Write-Host "   [OK] Node Group Status: $NgStatus" -ForegroundColor Green
} else {
    Write-Host "   [NOT CREATED] Node Group does not exist yet" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" -ForegroundColor Yellow
Write-Host "═════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "DEPLOYMENT STATUS SUMMARY" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════" -ForegroundColor Cyan

if ($ClusterRole -and $NodeRole -and $ClusterStatus -eq "ACTIVE" -and $NgStatus -eq "ACTIVE") {
    Write-Host "Status: READY FOR APPLICATION DEPLOYMENT" -ForegroundColor Green
    Write-Host "Next: Run .\build-and-push-images.ps1" -ForegroundColor Green
} elseif ($ClusterRole -and $NodeRole) {
    Write-Host "Status: READY FOR CLUSTER DEPLOYMENT" -ForegroundColor Green
    Write-Host "Next: Run .\deploy-with-existing-roles.ps1" -ForegroundColor Green
} else {
    Write-Host "Status: NOT READY - IAM Roles Missing" -ForegroundColor Red
    Write-Host "Action: Create missing IAM roles and try again" -ForegroundColor Yellow
}

Write-Host "═════════════════════════════════════════" -ForegroundColor Cyan
