#Requires -Version 5.1
# Launch Jenkins EC2 Instance with Ubuntu 22.04 LTS using AWS CLI
# This script creates an EC2 instance with Ubuntu for better Java support

param(
    [string]$InstanceName = "jenkins-ubuntu",
    [string]$InstanceType = "t3.medium",
    [string]$Region = "ap-southeast-2",
    [string]$KeyName = "jenkins-key",
    [string]$VpcId = "vpc-0e8c4c6d3f8e1b2c4",
    [string]$SubnetId = "subnet-0f1a2b3c4d5e6f7g8"
)

Write-Host "[*] Launching Jenkins EC2 Instance with Ubuntu 22.04 LTS..." -ForegroundColor Cyan

# Find latest Ubuntu 22.04 LTS AMI
Write-Host "[*] Finding latest Ubuntu 22.04 LTS AMI..." -ForegroundColor Yellow

$amiJson = aws ec2 describe-images `
    --region $Region `
    --owners 099720109477 `
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" `
              "Name=root-device-type,Values=ebs" `
              "Name=virtualization-type,Values=hvm" `
    --query "sort_by(Images, &CreationDate)[-1]" `
    --output json | ConvertFrom-Json

if (-not $amiJson.ImageId) {
    Write-Host "[ERROR] Could not find Ubuntu 22.04 LTS AMI!" -ForegroundColor Red
    exit 1
}

$imageId = $amiJson.ImageId
Write-Host "[OK] Found AMI: $imageId" -ForegroundColor Green

# Create security group
Write-Host "[*] Creating security group..." -ForegroundColor Yellow
$sgName = "jenkins-ubuntu-sg"
$sgCheck = aws ec2 describe-security-groups `
    --region $Region `
    --filters "Name=group-name,Values=$sgName" `
    --query "SecurityGroups[0].GroupId" `
    --output text 2>$null

if ($sgCheck -ne "None" -and $sgCheck) {
    Write-Host "[OK] Using existing security group: $sgCheck" -ForegroundColor Green
    $securityGroupId = $sgCheck
} else {
    Write-Host "[*] Creating new security group..." -ForegroundColor Gray
    
    $sgJson = aws ec2 create-security-group `
        --group-name $sgName `
        --description "Security group for Jenkins on Ubuntu" `
        --vpc-id $VpcId `
        --region $Region `
        --output json | ConvertFrom-Json
    
    $securityGroupId = $sgJson.GroupId
    Write-Host "[OK] Created security group: $securityGroupId" -ForegroundColor Green
    
    # Get user's public IP
    Write-Host "[*] Detecting your public IP..." -ForegroundColor Gray
    try {
        $myPublicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 5).Content.Trim()
        Write-Host "[OK] Your IP: $myPublicIP" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Could not auto-detect IP, using 0.0.0.0/0" -ForegroundColor Yellow
        $myPublicIP = "0.0.0.0/0"
    }
    
    # Add security group rules
    Write-Host "[*] Configuring security group rules..." -ForegroundColor Gray
    
    # SSH (22)
    aws ec2 authorize-security-group-ingress `
        --group-id $securityGroupId `
        --protocol tcp `
        --port 22 `
        --cidr $myPublicIP `
        --region $Region 2>$null
    
    # Jenkins UI (8080)
    aws ec2 authorize-security-group-ingress `
        --group-id $securityGroupId `
        --protocol tcp `
        --port 8080 `
        --cidr $myPublicIP `
        --region $Region 2>$null
    
    # Jenkins Agents (50000)
    aws ec2 authorize-security-group-ingress `
        --group-id $securityGroupId `
        --protocol tcp `
        --port 50000 `
        --cidr $myPublicIP `
        --region $Region 2>$null
    
    Write-Host "[OK] Security group rules configured" -ForegroundColor Green
}

# Launch EC2 instance
Write-Host "[*] Launching Ubuntu EC2 instance..." -ForegroundColor Yellow

$runJson = aws ec2 run-instances `
    --image-id $imageId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $securityGroupId `
    --subnet-id $SubnetId `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName},{Key=Environment,Value=development},{Key=Purpose,Value=Jenkins-CI CD}]" `
    --region $Region `
    --output json | ConvertFrom-Json

$instanceId = $runJson.Instances[0].InstanceId
Write-Host "[OK] Instance launched: $instanceId" -ForegroundColor Green

# Wait for public IP
Write-Host "[*] Waiting for instance to get public IP..." -ForegroundColor Yellow
$maxWait = 60
$elapsed = 0
$publicIp = $null
$privateIp = $null

while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds 5
    
    $instanceJson = aws ec2 describe-instances `
        --instance-ids $instanceId `
        --region $Region `
        --query "Reservations[0].Instances[0]" `
        --output json | ConvertFrom-Json
    
    if ($instanceJson.PublicIpAddress) {
        $publicIp = $instanceJson.PublicIpAddress
        $privateIp = $instanceJson.PrivateIpAddress
        $status = $instanceJson.State.Name
        Write-Host "[OK] Instance is $status" -ForegroundColor Green
        Write-Host "[OK] Public IP: $publicIp" -ForegroundColor Green
        Write-Host "[OK] Private IP: $privateIp" -ForegroundColor Green
        break
    }
    
    $elapsed += 5
    Write-Host "[*] Waiting... ($($elapsed)s)" -ForegroundColor Gray
}

if (-not $publicIp) {
    Write-Host "[ERROR] Timeout waiting for public IP!" -ForegroundColor Red
    exit 1
}

# Save instance details
$detailsFile = "d:\AI Work\ai-chatbot-devops\jenkins-ubuntu-instance.txt"
@"
Jenkins Ubuntu Instance Details
================================
Instance ID: $instanceId
Instance Name: $InstanceName
Instance Type: $InstanceType
Region: $Region
AMI ID: $imageId
OS: Ubuntu 22.04 LTS
Public IP: $publicIp
Private IP: $privateIp
Security Group: $securityGroupId
Subnet: $SubnetId
Key Name: $KeyName
Key File Path: $env:USERPROFILE\.ssh\$KeyName.pem

SSH Command:
ssh -i `$env:USERPROFILE\.ssh\$KeyName.pem ubuntu@$publicIp

Status: Running
Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Next Steps:
1. Wait 60 seconds for instance to fully boot
2. Connect via SSH: ssh -i path/to/$KeyName.pem ubuntu@$publicIp
3. Run setup on instance: bash ~/setup-jenkins-ubuntu.sh
"@ | Set-Content $detailsFile

Write-Host ""
Write-Host "[OK] Jenkins Ubuntu instance created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Instance Details:" -ForegroundColor Cyan
Write-Host "   Instance ID: $instanceId"
Write-Host "   Public IP: $publicIp"
Write-Host "   Private IP: $privateIp"
Write-Host "   SSH Username: ubuntu (not ec2-user)"
Write-Host ""
Write-Host "SSH Command:" -ForegroundColor Cyan
Write-Host "   ssh -i path/to\/jenkins-key.pem ubuntu@$publicIp" -ForegroundColor Yellow
Write-Host ""
Write-Host "[*] Next steps:"
Write-Host "   1. Wait 60 seconds for full initialization"
Write-Host "   2. SSH into instance"
Write-Host "   3. Run: bash ~/setup-jenkins-ubuntu.sh"
Write-Host ""
Write-Host "   Details saved to: $detailsFile"
