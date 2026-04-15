param(
    [string]$KeyName = "jenkins-key",
    [string]$InstanceName = "jenkins-controller",
    [string]$InstanceType = "t3.medium",
    [string]$Region = "ap-southeast-2",
    [string]$SecurityGroupName = "jenkins-security-group"
)

Write-Host "Launching Jenkins EC2 Instance" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
Write-Host "Checking AWS CLI..." -ForegroundColor Green
$awsVersion = aws --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AWS CLI not installed!" -ForegroundColor Red
    exit 1
}
Write-Host "Found: $awsVersion" -ForegroundColor Green
Write-Host ""

# STEP 1: Create or verify key pair
Write-Host "STEP 1: Checking key pair..." -ForegroundColor Cyan
$keyExists = aws ec2 describe-key-pairs --key-names $KeyName --region $Region 2>&1 | Select-String "KeyName"

if ($keyExists) {
    Write-Host "Key pair '$KeyName' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating new key pair '$KeyName'..." -ForegroundColor Yellow
    
    $outputDir = "$PSScriptRoot\..\keys"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    
    $keyPath = "$outputDir\$KeyName.pem"
    
    aws ec2 create-key-pair --key-name $KeyName --region $Region --query 'KeyMaterial' --output text | Out-File -FilePath $keyPath -Encoding UTF8
    icacls $keyPath /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    
    Write-Host "Key pair created at: $keyPath" -ForegroundColor Green
}
Write-Host ""

# STEP 2: Create or verify security group
Write-Host "STEP 2: Checking security group..." -ForegroundColor Cyan

# First, find which VPC has subnets (we'll use that VPC)
$subnetInfo = aws ec2 describe-subnets --region $Region --query 'Subnets[0].[SubnetId,VpcId]' --output text
$parts = $subnetInfo -split '\s+'
$subnetId = $parts[0]
$actualVpcId = $parts[1]

Write-Host "Will use VPC: $actualVpcId (has available subnets)" -ForegroundColor Yellow

$sgResult = aws ec2 describe-security-groups --filters "Name=group-name,Values=$SecurityGroupName" --region $Region 2>&1
$sgExists = $sgResult | Select-String "GroupId"

if ($sgExists) {
    Write-Host "Security group '$SecurityGroupName' already exists" -ForegroundColor Green
    $sgId = aws ec2 describe-security-groups --filters "Name=group-name,Values=$SecurityGroupName" --region $Region --query 'SecurityGroups[0].GroupId' --output text
} else {
    Write-Host "Creating security group '$SecurityGroupName' in correct VPC..." -ForegroundColor Yellow
    $sgId = aws ec2 create-security-group --group-name $SecurityGroupName --description "Security group for Jenkins controller" --vpc-id $actualVpcId --region $Region --query 'GroupId' --output text
    Write-Host "Security group created: $sgId" -ForegroundColor Green
}
Write-Host ""

# STEP 3: Get your IP
Write-Host "STEP 3: Detecting your IP..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5
    $myPublicIp = $response.ip
    Write-Host "Your IP: $myPublicIp" -ForegroundColor Green
} catch {
    Write-Host "Could not automatically detect IP. Enter your public IP: " -ForegroundColor Yellow -NoNewline
    $myPublicIp = Read-Host
}
Write-Host ""

# STEP 4: Add firewall rules
Write-Host "STEP 4: Adding firewall rules..." -ForegroundColor Cyan

$existingRules = aws ec2 describe-security-groups --group-ids $sgId --region $Region --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort]' --output text

if ($existingRules -notmatch "22") {
    Write-Host "Adding SSH rule..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 22 --cidr "$myPublicIp/32" --region $Region | Out-Null
}

if ($existingRules -notmatch "8080") {
    Write-Host "Adding Jenkins rule..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 8080 --cidr "$myPublicIp/32" --region $Region | Out-Null
}

if ($existingRules -notmatch "50000") {
    Write-Host "Adding agent rule..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 50000 --cidr "$myPublicIp/32" --region $Region | Out-Null
}
Write-Host "Firewall rules configured" -ForegroundColor Green
Write-Host ""

# STEP 5: Find/create subnet
Write-Host "STEP 5: Checking VPC and subnets..." -ForegroundColor Cyan

# Get the first available subnet (we already got this info earlier)
$subnet = aws ec2 describe-subnets --region $Region --query 'Subnets[0].SubnetId' --output text
$subnetId = $subnet
Write-Host "Using subnet: $subnetId" -ForegroundColor Green
Write-Host ""

# STEP 6: Find latest AMI
Write-Host "STEP 6: Finding latest Amazon Linux 2 AMI..." -ForegroundColor Cyan
$amiId = aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text --region $Region
Write-Host "AMI: $amiId" -ForegroundColor Green
Write-Host ""

# STEP 6: Launch instance
Write-Host "STEP 7: Launching EC2 instance..." -ForegroundColor Cyan
Write-Host "Instance type: $InstanceType" -ForegroundColor DarkGray
Write-Host "Region: $Region" -ForegroundColor DarkGray
Write-Host ""

$bdm = 'DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3,DeleteOnTermination=true}'
$instanceId = aws ec2 run-instances --image-id $amiId --instance-type $InstanceType --key-name $KeyName --security-group-ids $sgId --subnet-id $subnetId --block-device-mappings $bdm --associate-public-ip-address --region $Region --query 'Instances[0].InstanceId' --output text

Write-Host "Instance launched with ID: $instanceId" -ForegroundColor Green
Write-Host ""

# STEP 7: Wait for instance to be running
Write-Host "STEP 8: Waiting for instance to start (30-60 seconds)..." -ForegroundColor Cyan
$maxAttempts = 60
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $state = aws ec2 describe-instances --instance-ids $instanceId --region $Region --query 'Reservations[0].Instances[0].State.Name' --output text
    
    if ($state -eq "running") {
        Write-Host "Instance is running!" -ForegroundColor Green
        break
    }
    
    $attempt++
    if ($attempt % 10 -eq 0) {
        Write-Host "Still waiting... attempt $attempt/60" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1
}
Write-Host ""

# STEP 8: Get instance details
Write-Host "STEP 9: Retrieving instance details..." -ForegroundColor Cyan
$instanceInfo = aws ec2 describe-instances --instance-ids $instanceId --region $Region --query 'Reservations[0].Instances[0]'
$parsed = $instanceInfo | ConvertFrom-Json
$publicIp = $parsed.PublicIpAddress
$privateIp = $parsed.PrivateIpAddress

Write-Host "Instance Name: $InstanceName" -ForegroundColor Cyan
Write-Host "Instance ID: $instanceId" -ForegroundColor Cyan
Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
Write-Host "Private IP: $privateIp" -ForegroundColor Cyan
Write-Host "Key Name: $KeyName" -ForegroundColor Cyan
Write-Host "Security Group: $SecurityGroupName" -ForegroundColor Cyan
Write-Host ""

# STEP 9: Save configuration
Write-Host "STEP 10: Saving configuration..." -ForegroundColor Cyan
$configFile = "$PSScriptRoot\..\jenkins-ec2-config.txt"
$configContent = "EC2 Instance Created: $(Get-Date)`n`nInstance Details:`n"
$configContent += "Instance ID: $instanceId`n"
$configContent += "Instance Type: $InstanceType`n"
$configContent += "AMI ID: $amiId`n"
$configContent += "Public IP: $publicIp`n"
$configContent += "Private IP: $privateIp`n"
$configContent += "Region: $Region`n`n"
$configContent += "Access Details:`n"
$configContent += "Key Name: $KeyName`n"
$configContent += "Key Path: $PSScriptRoot\keys\$KeyName.pem`n"
$configContent += "Security Group: $SecurityGroupName`n"
$configContent += "Your IP: $myPublicIp`n`n"
$configContent += "SSH Command:`n"
$configContent += "ssh -i 'keys\$KeyName.pem' ec2-user@$publicIp`n`n"
$configContent += "Jenkins URL:`n"
$configContent += "http://$publicIp:8080`n"

$configContent | Out-File -FilePath $configFile -Encoding UTF8
Write-Host "Configuration saved to: $configFile" -ForegroundColor Green
Write-Host ""

# STEP 10: Tag instance
Write-Host "STEP 11: Tagging instance..." -ForegroundColor Cyan
aws ec2 create-tags --resources $instanceId --tags "Key=Name,Value=$InstanceName" "Key=Purpose,Value=Jenkins Controller" --region $Region
Write-Host "Instance tagged successfully" -ForegroundColor Green
Write-Host ""

# Completion
Write-Host "=================" -ForegroundColor Green
Write-Host "SUCCESS!" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host ""

Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. SSH into instance (wait 2-3 minutes first):" -ForegroundColor Yellow
Write-Host "   ssh -i 'keys\$KeyName.pem' ec2-user@$publicIp" -ForegroundColor White
Write-Host ""
Write-Host "2. Then run the setup script (from EC2 Step 4):" -ForegroundColor Yellow
Write-Host "   See: EC2_JENKINS_SETUP_STEPS.md" -ForegroundColor White
Write-Host ""
Write-Host "3. Access Jenkins at:" -ForegroundColor Yellow
Write-Host "   http://$publicIp:8080" -ForegroundColor White
Write-Host ""

Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "Instance ID: $instanceId" -ForegroundColor White
Write-Host "Public IP: $publicIp" -ForegroundColor White
Write-Host "Keep your key file safe!" -ForegroundColor White
Write-Host ""
