# Launch Jenkins EC2 Instance with Ubuntu 22.04 LTS
# This script creates an EC2 instance with Ubuntu (instead of Amazon Linux)
# for better Java 17/21 support

param(
    [string]$InstanceName = "jenkins-ubuntu",
    [string]$InstanceType = "t3.medium",
    [string]$Region = "ap-southeast-2",
    [string]$KeyName = "jenkins-key",
    [string]$VpcId = "vpc-0e8c4c6d3f8e1b2c4",
    [string]$SubnetId = "subnet-0f1a2b3c4d5e6f7g8"
)

# Import AWS modules
Write-Host "[*] Loading AWS PowerShell modules..." -ForegroundColor Yellow
Import-Module AWSPowerShell.NetCore -ErrorAction SilentlyContinue
Import-Module AWSPowerShell -ErrorAction SilentlyContinue

Write-Host "[*] Launching Jenkins EC2 Instance with Ubuntu 22.04 LTS..." -ForegroundColor Cyan

# Get the latest Ubuntu 22.04 LTS AMI in the specified region
Write-Host "[*] Finding latest Ubuntu 22.04 LTS AMI..." -ForegroundColor Yellow
$amiFilter = @(
    @{
        Name   = "name"
        Values = @("ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*")
    },
    @{
        Name   = "root-device-type"
        Values = @("evm")
    },
    @{
        Name   = "virtualization-type"
        Values = @("hvm")
    }
)

$images = Get-EC2Image -Region $Region -Filter $amiFilter -Owner 099720109477 | 
    Sort-Object -Property CreationDate -Descending | 
    Select-Object -First 1

if (-not $images) {
    Write-Host "[ERROR] Could not find Ubuntu 22.04 LTS AMI!" -ForegroundColor Red
    exit 1
}

$imageId = $images.ImageId
Write-Host "[OK] Found AMI: $imageId" -ForegroundColor Green

# Create security group if it doesn't exist
Write-Host "[*] Configuring security group..." -ForegroundColor Yellow
$sgName = "jenkins-ubuntu-sg"
$existingSG = Get-EC2SecurityGroup -Region $Region -Filter @{Name = "group-name"; Values = @($sgName)} -ErrorAction SilentlyContinue

if ($existingSG) {
    $securityGroupId = $existingSG[0].GroupId
    Write-Host "[OK] Using existing security group: $securityGroupId" -ForegroundColor Green
} else {
    Write-Host "[*] Creating new security group..." -ForegroundColor Gray
    $sig = New-EC2SecurityGroup -GroupName $sgName `
        -GroupDescription "Security group for Jenkins on Ubuntu" `
        -VpcId $VpcId `
        -Region $Region
    $securityGroupId = $sig.GroupId
    Write-Host "[OK] Created security group: $securityGroupId" -ForegroundColor Green
    
    # Get user's public IP for SSH access
    Write-Host "[*] Detecting your public IP..." -ForegroundColor Gray
    try {
        $myPublicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
        Write-Host "[OK] Your IP: $myPublicIP" -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Could not auto-detect IP, using 0.0.0.0/0 (less secure)" -ForegroundColor Yellow
        $myPublicIP = "0.0.0.0/0"
    }
    
    # Add inbound rules
    $ipPermissions = @(
        @{
            IpProtocol = "tcp"
            FromPort   = 22
            ToPort     = 22
            IpRanges   = @(@{CidrIp = $myPublicIP; Description = "SSH access" })
        },
        @{
            IpProtocol = "tcp"
            FromPort   = 8080
            ToPort     = 8080
            IpRanges   = @(@{CidrIp = $myPublicIP; Description = "Jenkins UI" })
        },
        @{
            IpProtocol = "tcp"
            FromPort   = 50000
            ToPort     = 50000
            IpRanges   = @(@{CidrIp = $myPublicIP; Description = "Jenkins agents" })
        }
    )
    
    Grant-EC2SecurityGroupIngress -GroupId $securityGroupId -IpPermission $ipPermissions -Region $Region
    Write-Host "[OK] Security group rules configured" -ForegroundColor Green
}

# Launch the EC2 instance
Write-Host "[*] Launching Ubuntu EC2 instance..." -ForegroundColor Yellow
$runResult = New-EC2Instance -ImageId $imageId `
    -MinCount 1 `
    -MaxCount 1 `
    -InstanceType $InstanceType `
    -KeyName $KeyName `
    -SecurityGroupId $securityGroupId `
    -SubnetId $SubnetId `
    -Region $Region `
    -TagSpecification @(
    @{
        ResourceType = "instance"
        Tags         = @(
            @{Key = "Name"; Value = $InstanceName }
            @{Key = "Environment"; Value = "development" }
            @{Key = "Purpose"; Value = "Jenkins CI/CD" }
        )
    }
)

$instanceId = $runResult.Instances[0].InstanceId
Write-Host "[OK] Instance launched: $instanceId" -ForegroundColor Green

# Wait for instance to get a public IP
Write-Host "[*] Waiting for instance to start and get public IP..." -ForegroundColor Yellow
$maxWait = 60
$elapsed = 0

while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds 5
    $instance = Get-EC2Instance -InstanceId $instanceId -Region $Region | Select-Object -ExpandProperty Instances
    
    if ($instance[0].PublicIpAddress) {
        $publicIp = $instance[0].PublicIpAddress
        $privateIp = $instance[0].PrivateIpAddress
        $status = $instance[0].State.Name
        Write-Host "[OK] Instance is $status" -ForegroundColor Green
        Write-Host "[OK] Public IP: $publicIp" -ForegroundColor Green
        Write-Host "[OK] Private IP: $privateIp" -ForegroundColor Green
        break
    }
    
    $elapsed += 5
    Write-Host "[*] Waiting... ($($elapsed) seconds)" -ForegroundColor Gray
}

if (-not $publicIp) {
    Write-Host "[ERROR] Timeout waiting for public IP!" -ForegroundColor Red
    exit 1
}

# Save instance details to file
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
Key File Path: d:\AI Work\ai-chatbot-devops\keys\$KeyName.pem

SSH Command:
ssh -i "d:\AI Work\ai-chatbot-devops\keys\$KeyName.pem" ubuntu@$publicIp

Status: Running
Created: $(Get-Date)

Next Steps:
1. Wait 60 seconds for instance to fully initialize
2. Connect via SSH using command above (use ubuntu username for Ubuntu)
3. Run setup script: bash scripts/setup-jenkins-ubuntu.sh
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
Write-Host "   ssh -i `"d:\AI Work\ai-chatbot-devops\keys\$KeyName.pem`" ubuntu@$publicIp" -ForegroundColor Yellow
Write-Host ""
Write-Host "[*] Wait 60 seconds for the instance to fully initialize, then:"
Write-Host "   1. Connect via SSH"
Write-Host "   2. Run: bash ~/setup-jenkins-ubuntu.sh"
Write-Host ""
Write-Host "Details saved to: $detailsFile"
