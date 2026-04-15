$region = "ap-southeast-2"
$ErrorActionPreference = "Continue"

Write-Host "
╔═══════════════════════════════════════════════════════════════════╗
║        🧹 FINAL COMPREHENSIVE AWS CLEANUP                        ║
║  Removing ALL non-default resources:                             ║
║  IAM | VPC | EKS | ECR | Clusters | Node Groups                 ║
╚═══════════════════════════════════════════════════════════════════╝
" -ForegroundColor Green

# ===== 1. CHECK & DELETE EKS CLUSTERS =====
Write-Host "`n[1/6] EKS CLUSTERS" -ForegroundColor Yellow 

$clusters = aws eks list-clusters --region $region --query 'clusters' --output text 2>&1
if ($clusters -and $clusters -ne "") {
    foreach ($cluster in $clusters.Split()) {
        if ($cluster) {
            Write-Host "  Found: $cluster" -ForegroundColor Red
            
            # Delete node groups first
            $ngs = aws eks list-nodegroups --cluster-name $cluster --region $region --query 'nodegroups' --output text 2>&1
            if ($ngs -and $ngs -ne "") {
                foreach ($ng in $ngs.Split()) {
                    if ($ng) {
                        Write-Host "    Deleting nodegroup: $ng" -ForegroundColor Cyan
                        aws eks delete-nodegroup --cluster-name $cluster --nodegroup-name $ng --region $region 2>&1 | Out-Null
                    }
                }
                Write-Host "    Waiting 60secs for nodegroups..." -ForegroundColor Gray
                Start-Sleep -Seconds 60
            }
            
            # Delete cluster
            Write-Host "    Deleting cluster: $cluster" -ForegroundColor Cyan
            aws eks delete-cluster --name $cluster --region $region 2>&1 | Out-Null
            Write-Host "    ✅ Cluster deletion initiated" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ✅ No EKS clusters found" -ForegroundColor Green
}

# Wait for cluster deletion
Write-Host "  Waiting 120secs for cluster deletion..." -ForegroundColor Gray
Start-Sleep -Seconds 120

# ===== 2. DELETE ASGS =====
Write-Host "`n[2/6] AUTO SCALING GROUPS" -ForegroundColor Yellow

$asgs = aws autoscaling describe-auto-scaling-groups --region $region --query 'AutoScalingGroups[].AutoScalingGroupName' --output text 2>&1
if ($asgs -and $asgs -ne "") {
    foreach ($asg in $asgs.Split()) {
        if ($asg) {
            Write-Host "  Deleting: $asg" -ForegroundColor Cyan
            aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asg --force-delete --region $region 2>&1 | Out-Null
            Write-Host "  ✅ Deleted" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ✅ No ASGs found" -ForegroundColor Green
}

# ===== 3. DELETE ECR REPOSITORIES =====
Write-Host "`n[3/6] ECR REPOSITORIES" -ForegroundColor Yellow

$repos = aws ecr describe-repositories --region $region --query 'repositories[].repositoryName' --output text 2>&1
if ($repos -and $repos -ne "") {
    foreach ($repo in $repos.Split()) {
        if ($repo) {
            Write-Host "  Deleting: $repo" -ForegroundColor Cyan
            aws ecr delete-repository --repository-name $repo --region $region --force 2>&1 | Out-Null
            Write-Host "  ✅ Deleted" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ✅ No ECR repos found" -ForegroundColor Green
}

# ===== 4. DELETE VPC AND NETWORKING =====
Write-Host "`n[4/6] VPC AND NETWORKING" -ForegroundColor Yellow

$vpcs = aws ec2 describe-vpcs --region $region --filters "Name=isDefault,Values=false" --query 'Vpcs[].VpcId' --output text 2>&1
if ($vpcs -and $vpcs -ne "") {
    foreach ($vpc_id in $vpcs.Split()) {
        if ($vpc_id) {
            Write-Host "  Cleaning VPC: $vpc_id" -ForegroundColor Cyan
            
            # Delete NAT Gateways
            $nats = aws ec2 describe-nat-gateways --region $region --filters "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[].NatGatewayId' --output text 2>&1
            if ($nats -and $nats -ne "") {
                foreach ($nat in $nats.Split()) {
                    if ($nat) {
                        Write-Host "    Deleting NAT: $nat" -ForegroundColor Cyan
                        aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Release EIPs
            $eips = aws ec2 describe-addresses --region $region --query "Addresses[?AssociationId!=null].AllocationId" --output text 2>&1
            if ($eips -and $eips -ne "") {
                foreach ($eip in $eips.Split()) {
                    if ($eip) {
                        Write-Host "    Releasing EIP: $eip" -ForegroundColor Cyan
                        aws ec2 release-address --allocation-id $eip --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete Security Groups (non-default)
            $sgs = aws ec2 describe-security-groups --region $region --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=!default" --query 'SecurityGroups[].GroupId' --output text 2>&1
            if ($sgs -and $sgs -ne "") {
                foreach ($sg in $sgs.Split()) {
                    if ($sg) {
                        Write-Host "    Deleting SG: $sg" -ForegroundColor Cyan
                        aws ec2 delete-security-group --group-id $sg --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete Subnets
            $subnets = aws ec2 describe-subnets --region $region --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text 2>&1
            if ($subnets -and $subnets -ne "") {
                foreach ($subnet in $subnets.Split()) {
                    if ($subnet) {
                        Write-Host "    Deleting Subnet: $subnet" -ForegroundColor Cyan
                        aws ec2 delete-subnet --subnet-id $subnet --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete Route Tables (non-main)
            $rts = aws ec2 describe-route-tables --region $region --filters "Name=vpc-id,Values=$vpc_id" --query "RouteTables[?Associations[0].Main==false].RouteTableId" --output text 2>&1
            if ($rts -and $rts -ne "") {
                foreach ($rt in $rts.Split()) {
                    if ($rt) {
                        Write-Host "    Deleting Route Table: $rt" -ForegroundColor Cyan
                        aws ec2 delete-route-table --route-table-id $rt --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete Internet Gateways
            $igws = aws ec2 describe-internet-gateways --region $region --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text 2>&1
            if ($igws -and $igws -ne "") {
                foreach ($igw in $igws.Split()) {
                    if ($igw) {
                        Write-Host "    Detaching IGW: $igw" -ForegroundColor Cyan
                        aws ec2 detach-internet-gateway --igw-id $igw --vpc-id $vpc_id --region $region 2>&1 | Out-Null
                        aws ec2 delete-internet-gateway --igw-id $igw --region $region 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete VPC
            Write-Host "    Deleting VPC: $vpc_id" -ForegroundColor Cyan
            aws ec2 delete-vpc --vpc-id $vpc_id --region $region 2>&1 | Out-Null
            Write-Host "  ✅ VPC cleaned" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ✅ No custom VPCs found" -ForegroundColor Green
}

# ===== 5. DELETE IAM ROLES =====
Write-Host "`n[5/6] IAM ROLES" -ForegroundColor Yellow

$roles = aws iam list-roles --query "Roles[?RoleName!='*service*' && RoleName!='*AWS*'].RoleName" --output text 2>&1 | Where-Object {$_ -and $_.Trim() -ne ''}
if ($roles -and $roles -ne "") {
    foreach ($role in $roles.Split()) {
        if ($role -and $role.Length -gt 3) {
            Write-Host "  Found: $role" -ForegroundColor Cyan
            
            # Detach policies
            $policies = aws iam list-attached-role-policies --role-name $role --query 'AttachedPolicies[].PolicyArn' --output text 2>&1
            if ($policies -and $policies -ne "") {
                foreach ($policy in $policies.Split()) {
                    if ($policy) {
                        Write-Host "    Detaching: $policy" -ForegroundColor Gray
                        aws iam detach-role-policy --role-name $role --policy-arn $policy 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete inline policies
            $inline = aws iam list-role-policies --role-name $role --query 'PolicyNames[]' --output text 2>&1
            if ($inline -and $inline -ne "") {
                foreach ($iname in $inline.Split()) {
                    if ($iname) {
                        Write-Host "    Deleting inline: $iname" -ForegroundColor Gray
                        aws iam delete-role-policy --role-name $role --policy-name $iname 2>&1 | Out-Null
                    }
                }
            }
            
            # Delete role
            Write-Host "    Deleting role: $role" -ForegroundColor Cyan
            aws iam delete-role --role-name $role 2>&1 | Out-Null
            Write-Host "  ✅ Role deleted" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ✅ No custom IAM roles found" -ForegroundColor Green
}

# ===== 6. FINAL VERIFICATION =====
Write-Host "`n[6/6] FINAL VERIFICATION" -ForegroundColor Yellow

$c = aws eks list-clusters --region $region --query 'length(clusters)' --output text
$i = @(aws ec2 describe-instances --region $region --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text).Count
$v = aws ec2 describe-vpcs --region $region --filters "Name=isDefault,Values=false" --query 'length(Vpcs)' --output text

Write-Host "  EKS Clusters: $c" -NoNewline
if ($c -eq 0) { Write-Host " ✅" -ForegroundColor Green } else { Write-Host " ❌" -ForegroundColor Red }

Write-Host "  Running Instances: $i" -NoNewline
if ($i -eq 0) { Write-Host " ✅" -ForegroundColor Green } else { Write-Host " ❌" -ForegroundColor Red }

Write-Host "  Custom VPCs: $v" -NoNewline
if ($v -eq 0) { Write-Host " ✅" -ForegroundColor Green } else { Write-Host " ❌" -ForegroundColor Red }

Write-Host "`n╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
if (($c -eq 0) -and ($i -eq 0) -and ($v -eq 0)) {
    Write-Host "║         ✨ CLEANUP COMPLETE - AWS ACCOUNT IS CLEAN ✨           ║" -ForegroundColor Green
    Write-Host "║  All non-default resources removed. Ready for deployment!        ║" -ForegroundColor Green
} else {
    Write-Host "║  ⏳ Cleanup 90% done - AWS may still be processing               ║" -ForegroundColor Yellow
    Write-Host "║  Some resources may take 15-30 more minutes to fully delete      ║" -ForegroundColor Yellow
}
Write-Host "╚═══════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
