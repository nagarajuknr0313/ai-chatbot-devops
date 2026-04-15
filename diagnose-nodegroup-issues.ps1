##############################################################################
# EKS Node Group Recovery - Diagnostic & Fix
# Identifies and fixes node group creation failures
##############################################################################

param(
    [string]$Region = "ap-southeast-2",
    [string]$ClusterName = "ai-chatbot-cluster",
    [string]$ProjectName = "ai-chatbot"
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

function Write-OK { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Step { Write-Host "`n=== $args ===" -ForegroundColor Yellow }

$StartTime = Get-Date
Write-Host "EKS Node Group Recovery - Started" -ForegroundColor Cyan

# === STEP 1: Check Cluster Health ===
Write-Step "Cluster Health Check"

$cluster = aws eks describe-cluster --name $ClusterName --region $Region --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($cluster.cluster) {
    Write-OK "Cluster found: $($cluster.cluster.name)"
    Write-Info "Status: $($cluster.cluster.status)"
    Write-Info "Platform Version: $($cluster.cluster.platformVersion)"
    Write-Info "Endpoint: $($cluster.cluster.endpoint)"
} else {
    Write-Err "Cluster not found or error querying"
    exit 1
}

# === STEP 2: Delete Failed Node Group ===
Write-Step "Cleaning Up Failed Node Group"

$ngStatus = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
    --region $Region --query 'nodegroup.status' --output text 2>&1

if ($ngStatus -and $ngStatus -ne "None") {
    Write-Info "Current status: $ngStatus"
    Write-Info "Deleting node group..."
    
    aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
        --region $Region 2>&1 | Out-Null
    
    # Wait for deletion
    $elapsed = 0
    while ($elapsed -lt 600) {
        Start-Sleep -Seconds 10
        $status = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name "$ProjectName-node-group" `
            --region $Region --query 'nodegroup.status' --output text 2>&1
        
        if ($status -like "*ResourceNotFoundException*" -or $status -like "*not found*") {
            Write-OK "Node group deleted successfully"
            break
        }
        Write-Host "  [$elapsed/600s] Deleting... Status: $status" -ForegroundColor Gray
        $elapsed += 10
    }
}

# === STEP 3: Security Group Analysis ===
Write-Step "Security Group Configuration"

$sgId = $cluster.cluster.resourcesVpcConfig.clusterSecurityGroupId
Write-Info "Cluster Security Group: $sgId"

$sg = aws ec2 describe-security-groups --group-ids $sgId --region $Region --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($sg.SecurityGroups) {
    $sgData = $sg.SecurityGroups[0]
    Write-Info "Group Name: $($sgData.GroupName)"
    Write-Info "VPC: $($sgData.VpcId)"
    
    Write-Host "`nIngress Rules:" -ForegroundColor Cyan
    if ($sgData.IpPermissions.Count -eq 0) {
        Write-Warn "NO INGRESS RULES! This would prevent node communication."
    } else {
        foreach ($rule in $sgData.IpPermissions) {
            $proto = if ($rule.IpProtocol -eq "-1") { "ALL" } else { $rule.IpProtocol }
            $ports = if ($rule.FromPort) { "$($rule.FromPort)-$($rule.ToPort)" } else { "ALL" }
            Write-Host "  Protocol: $proto, Ports: $ports" -ForegroundColor Gray
            if ($rule.UserIdGroupPairs) {
                Write-Host "    From Groups: $($rule.UserIdGroupPairs | ConvertTo-Json -Compress)" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`nEgress Rules:" -ForegroundColor Cyan
    foreach ($rule in $sgData.IpPermissionsEgress | Select-Object -First 3) {
        $proto = if ($rule.IpProtocol -eq "-1") { "ALL" } else { $rule.IpProtocol }
        $ports = if ($rule.FromPort) { "$($rule.FromPort)-$($rule.ToPort)" } else { "ALL" }
        Write-Host "  Protocol: $proto, Ports: $ports, CIDR: $($rule.IpRanges[0].CidrIp)" -ForegroundColor Gray
    }
}

# === STEP 4: Subnet Analysis ===
Write-Step "Subnet Configuration"

$vpcId = $cluster.cluster.resourcesVpcConfig.vpcId
Write-Info "VPC: $vpcId`n"

$subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --region $Region --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($subnets.Subnets) {
    foreach ($subnet in $subnets.Subnets) {
        $type = if ($subnet.MapPublicIpOnLaunch) { "PUBLIC" } else { "PRIVATE" }
        $marker = if ($subnet.SubnetId -in $cluster.cluster.resourcesVpcConfig.subnetIds) { "★" } else { " " }
        Write-Host "$marker [$type] $($subnet.SubnetId) $($subnet.CidrBlock) ($($subnet.AvailabilityZone))" -ForegroundColor Gray
    }
}

# === STEP 5: IAM Role Check ===
Write-Step "IAM Role Configuration"

$nodeRole = aws iam get-role --role-name "$ProjectName-eks-node-group-role" `
    --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($nodeRole.Role) {
    Write-OK "Node Role: $($nodeRole.Role.RoleName)"
    Write-Info "ARN: $($nodeRole.Role.Arn)"
    
    $policies = aws iam list-attached-role-policies --role-name "$ProjectName-eks-node-group-role" `
        --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($policies.AttachedPolicies) {
        Write-Host "`nAttached Policies:" -ForegroundColor Cyan
        foreach ($policy in $policies.AttachedPolicies) {
            Write-Host "  - $($policy.PolicyName)" -ForegroundColor Gray
        }
    }
} else {
    Write-Err "Node role not found"
}

# === STEP 6: Recommendation ===
Write-Step "Diagnosis Complete - Recommended Action"

Write-Host "`nBased on the analysis above:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Check CLUSTER SECURITY GROUP rules:" -ForegroundColor Yellow
Write-Host "   - Should allow ALL traffic from nodes to control plane" -ForegroundColor Gray
Write-Host "   - aws ec2 describe-security-groups --group-ids $sgId --region $Region" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Try t3.small instead of t3.medium:" -ForegroundColor Yellow
Write-Host "   - May have better availability in ap-southeast-2" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Use PUBLIC subnets ONLY for nodes:" -ForegroundColor Yellow
Write-Host "   - Avoids NAT complexity for initial testing" -ForegroundColor Gray
Write-Host ""
Write-Host "4. If issues persist:" -ForegroundColor Yellow
Write-Host "   - Check EC2 console for instance launch errors" -ForegroundColor Gray
Write-Host "   - Review VPC Flow Logs for network connectivity" -ForegroundColor Gray
Write-Host "   - Check CloudWatch logs for EKS cluster events" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Command: .\recover-nodegroup.ps1" -ForegroundColor Cyan
Write-Host "This creates a new node group with:" -ForegroundColor Cyan
Write-Host "  - Proper security group configuration" -ForegroundColor Gray
Write-Host "  - PUBLIC subnet placement" -ForegroundColor Gray
Write-Host "  - Instance type fallback" -ForegroundColor Gray
Write-Host "  - Extended logging" -ForegroundColor Gray

Write-OK "Diagnostic phase complete"
$Duration = (Get-Date) - $StartTime
Write-Info "Duration: $($Duration.TotalSeconds) seconds"
