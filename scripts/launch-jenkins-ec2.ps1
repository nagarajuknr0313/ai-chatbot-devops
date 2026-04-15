# ============================================
# Launch Jenkins EC2 Instance with AWS CLI
# ============================================
# PowerShell Script to automate EC2 instance creation

param(
    [string]$KeyName = "jenkins-key-pair",
    [string]$InstanceName = "jenkins-controller",
    [string]$InstanceType = "t3.medium",
    [string]$Region = "ap-southeast-2",
    [string]$SecurityGroupName = "jenkins-security-group"
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "🚀 Launching Jenkins EC2 Instance" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
Write-Host "✅ Checking AWS CLI..." -ForegroundColor Green
$awsVersion = aws --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ AWS CLI not installed!" -ForegroundColor Red
    Write-Host "Download from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}
Write-Host "Found: $awsVersion" -ForegroundColor Green
Write-Host ""

# Set region
Write-Host "📍 Using Region: $Region" -ForegroundColor Green
Write-Host ""

# ========== STEP 1: Create Key Pair ==========
Write-Host "STEP 1: Creating Key Pair..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$keyExists = aws ec2 describe-key-pairs --key-names $KeyName --region $Region 2>&1 | Select-String "KeyName"

if ($keyExists) {
    Write-Host "✅ Key pair '$KeyName' already exists" -ForegroundColor Green
} else {
    Write-Host "📝 Creating new key pair '$KeyName'..." -ForegroundColor Yellow
    
    $outputDir = "$PSScriptRoot\..\keys"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    
    $keyPath = "$outputDir\$KeyName.pem"
    
    aws ec2 create-key-pair `
        --key-name $KeyName `
        --region $Region `
        --query 'KeyMaterial' `
        --output text | Out-File -FilePath $keyPath -Encoding UTF8
    
    # Set permissions (Windows)
    icacls $keyPath /inheritance:r /grant:r "$($env:USERNAME):(F)" /grant "SYSTEM:(F)" | Out-Null
    
    Write-Host "✅ Key pair created at: $keyPath" -ForegroundColor Green
}

Write-Host ""

# ========== STEP 2: Create Security Group ==========
Write-Host "STEP 2: Creating Security Group..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$sgExists = aws ec2 describe-security-groups `
    --filters "Name=group-name,Values=$SecurityGroupName" `
    --region $Region 2>&1 | Select-String "jenkins-security-group"

if ($sgExists) {
    Write-Host "✅ Security group '$SecurityGroupName' already exists" -ForegroundColor Green
    $sgId = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$SecurityGroupName" `
        --region $Region `
        --query 'SecurityGroups[0].GroupId' `
        --output text
} else {
    Write-Host "📝 Creating new security group '$SecurityGroupName'..." -ForegroundColor Yellow
    
    # Get default VPC
    $vpcId = aws ec2 describe-vpcs `
        --filters "Name=isDefault,Values=true" `
        --region $Region `
        --query 'Vpcs[0].VpcId' `
        --output text
    
    $sgId = aws ec2 create-security-group `
        --group-name $SecurityGroupName `
        --description "Security group for Jenkins controller" `
        --vpc-id $vpcId `
        --region $Region `
        --query 'GroupId' `
        --output text
    
    Write-Host "✅ Security group created: $sgId" -ForegroundColor Green
}

Write-Host "📍 Security Group ID: $sgId" -ForegroundColor Green
Write-Host ""

# ========== STEP 3: Get Your IP ==========
Write-Host "STEP 3: Detecting Your IP Address..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "ℹ️  Fetching your public IP..." -ForegroundColor Yellow
try {
    $myIp = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5
    $myPublicIp = $myIp.ip
    Write-Host "✅ Your IP: $myPublicIp" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not determine public IP automatically" -ForegroundColor Yellow
    Write-Host "Enter your IP address (from https://www.whatismyip.com/): " -ForegroundColor Yellow -NoNewline
    $myPublicIp = Read-Host
}

Write-Host ""

# ========== STEP 4: Add Security Group Rules ==========
Write-Host "STEP 4: Adding Security Group Rules..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Check existing rules
$existingRules = aws ec2 describe-security-groups `
    --group-ids $sgId `
    --region $Region `
    --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort]' `
    --output text

# SSH (22)
if ($existingRules -notmatch "22") {
    Write-Host "📝 Adding SSH rule (port 22)..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp `
        --port 22 `
        --cidr "$myPublicIp/32" `
        --region $Region | Out-Null
    Write-Host "✅ SSH rule added" -ForegroundColor Green
} else {
    Write-Host "✅ SSH rule already exists" -ForegroundColor Green
}

# Jenkins (8080)
if ($existingRules -notmatch "8080") {
    Write-Host "📝 Adding Jenkins rule (port 8080)..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp `
        --port 8080 `
        --cidr "$myPublicIp/32" `
        --region $Region | Out-Null
    Write-Host "✅ Jenkins rule added" -ForegroundColor Green
} else {
    Write-Host "✅ Jenkins rule already exists" -ForegroundColor Green
}

# Jenkins Agents (50000)
if ($existingRules -notmatch "50000") {
    Write-Host "📝 Adding Jenkins agent rule (port 50000)..." -ForegroundColor Yellow
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp `
        --port 50000 `
        --cidr "$myPublicIp/32" `
        --region $Region | Out-Null
    Write-Host "✅ Jenkins agent rule added" -ForegroundColor Green
} else {
    Write-Host "✅ Jenkins agent rule already exists" -ForegroundColor Green
}

Write-Host ""

# ========== STEP 5: Get Latest Amazon Linux 2 AMI ==========
Write-Host "STEP 5: Finding Latest Amazon Linux 2 AMI..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "🔍 Searching for latest Amazon Linux 2 AMI..." -ForegroundColor Yellow
$amiId = aws ec2 describe-images `
    --owners amazon `
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" `
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' `
    --output text `
    --region $Region

Write-Host "✅ AMI: $amiId (Amazon Linux 2)" -ForegroundColor Green
Write-Host ""

# ========== STEP 6: Create EC2 Instance ==========
Write-Host "STEP 6: Launching EC2 Instance..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "📝 Launching instance..." -ForegroundColor Yellow
Write-Host "   Instance Type: $InstanceType" -ForegroundColor DarkGray
Write-Host "   Region: $Region" -ForegroundColor DarkGray
Write-Host "   Key Pair: $KeyName" -ForegroundColor DarkGray
Write-Host ""

$instanceId = aws ec2 run-instances `
    --image-id $amiId `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $sgId `
    --block-device-mappings "DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3,DeleteOnTermination=true}" `
    --region $Region `
    --query 'Instances[0].InstanceId' `
    --output text

Write-Host "✅ Instance launched!" -ForegroundColor Green
Write-Host "   Instance ID: $instanceId" -ForegroundColor Green
Write-Host ""

# ========== STEP 7: Wait for Instance to be Running ==========
Write-Host "STEP 7: Waiting for Instance to Start..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "⏳ Waiting for instance to start (this takes ~30-60 seconds)..." -ForegroundColor Yellow
$maxAttempts = 60
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $state = aws ec2 describe-instances `
        --instance-ids $instanceId `
        --region $Region `
        --query 'Reservations[0].Instances[0].State.Name' `
        --output text
    
    if ($state -eq "running") {
        Write-Host "✅ Instance is running!" -ForegroundColor Green
        break
    }
    
    $attempt++
    Write-Host "⏳ Status: $state (attempt $attempt/60)" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

Write-Host ""

# ========== STEP 8: Get Instance Details ==========
Write-Host "STEP 8: Retrieving Instance Details..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$instanceInfo = aws ec2 describe-instances `
    --instance-ids $instanceId `
    --region $Region `
    --query 'Reservations[0].Instances[0]'

$publicIp = $instanceInfo | ConvertFrom-Json | Select-Object -ExpandProperty PublicIpAddress
$privateIp = $instanceInfo | ConvertFrom-Json | Select-Object -ExpandProperty PrivateIpAddress

Write-Host "✅ Instance details retrieved:" -ForegroundColor Green
Write-Host ""

Write-Host "🏷️  Instance Name: $InstanceName" -ForegroundColor Cyan
Write-Host "🆔 Instance ID: $instanceId" -ForegroundColor Cyan
Write-Host "📍 Public IP: $publicIp" -ForegroundColor Cyan
Write-Host "📍 Private IP: $privateIp" -ForegroundColor Cyan
Write-Host "🔑 Key Name: $KeyName" -ForegroundColor Cyan
Write-Host "🛡️  Security Group: $SecurityGroupName ($sgId)" -ForegroundColor Cyan
Write-Host ""

# ========== STEP 9: Save Configuration ==========
Write-Host "STEP 9: Saving Configuration..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$configFile = "$PSScriptRoot\..\jenkins-ec2-config.txt"
$configContent = @"
Jenkins EC2 Instance Configuration
===================================
Created: $(Get-Date)

Instance Details:
- Instance ID: $instanceId
- Instance Type: $InstanceType
- AMI ID: $amiId
- Public IP: $publicIp
- Private IP: $privateIp
- Region: $Region

Access Details:
- Key Name: $KeyName
- Key Path: $PSScriptRoot\..\keys\$KeyName.pem
- Security Group: $SecurityGroupName ($sgId)
- Your IP: $myPublicIp

SSH Command:
ssh -i "keys\$KeyName.pem" ec2-user@$publicIp

Jenkins URL:
http://$publicIp:8080

Next Steps:
1. Wait 2-3 minutes for instance to fully initialize
2. SSH into the instance:
   ssh -i "keys\$KeyName.pem" ec2-user@$publicIp
3. Run the automated setup script on the EC2 instance
4. Access Jenkins at: http://$publicIp:8080
"@

$configContent | Out-File -FilePath $configFile -Encoding UTF8
Write-Host "✅ Configuration saved to: $configFile" -ForegroundColor Green
Write-Host ""

# ========== STEP 10: Tag Instance ==========
Write-Host "STEP 10: Tagging Instance..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

aws ec2 create-tags `
    --resources $instanceId `
    --tags "Key=Name,Value=$InstanceName" "Key=Purpose,Value=Jenkins Controller" "Key=Environment,Value=Production" `
    --region $Region

Write-Host "✅ Instance tagged successfully" -ForegroundColor Green
Write-Host ""

# ========== COMPLETION ==========
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ EC2 Instance Created Successfully!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

Write-Host "📋 NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣  SSH into your instance (wait 2-3 minutes first):" -ForegroundColor Yellow
Write-Host "   ssh -i ""keys\$KeyName.pem"" ec2-user@$publicIp" -ForegroundColor White
Write-Host ""
Write-Host "2️⃣  Then run the automated setup script:" -ForegroundColor Yellow
Write-Host "   (copy from scripts/jenkins-setup-ec2.sh)" -ForegroundColor White
Write-Host ""
Write-Host "3️⃣  Access Jenkins at:" -ForegroundColor Yellow
Write-Host "   http://$publicIp:8080" -ForegroundColor White
Write-Host ""

Write-Host "💾 Save these details:" -ForegroundColor Cyan
Write-Host "   Instance ID: $instanceId" -ForegroundColor White
Write-Host "   Public IP: $publicIp" -ForegroundColor White
Write-Host "   Key File: keys\$KeyName.pem" -ForegroundColor White
Write-Host ""

Write-Host "⚠️  IMPORTANT:" -ForegroundColor Yellow
Write-Host "   - Security group rules are restricted to your IP: $myPublicIp" -ForegroundColor DarkYellow
Write-Host "   - Keep your key file safe and never commit it to Git!" -ForegroundColor DarkYellow
Write-Host "   - Instance is in: $Region" -ForegroundColor DarkYellow
Write-Host ""
