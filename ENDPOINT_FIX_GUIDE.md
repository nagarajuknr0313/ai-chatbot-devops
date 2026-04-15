# EKS Node Health Issue - Root Cause Analysis & Solution

## The Real Problem

**Error Message**: `dial tcp: lookup 0D93D99A178EB4B5EAE52FCBE322AF19.sk1.ap-southeast-2.eks.amazonaws.com: no such host`

**Meaning**: Your local machine (or kubectl) **cannot resolve the EKS cluster endpoint hostname**.

This is NOT a problem with the nodes themselves - it's a **DNS resolution issue from your local machine**.

## Why This Happened

1. EKS created a cluster with a private managed endpoint
2. The endpoint is a hostname in AWS's private DNS
3. Your local machine doesn't have access to AWS private DNS
4. kubectl tries to connect but fails at DNS resolution

## The Solution

### Option 1: Quick Fix - Enable Public Endpoint (Recommended for Development)

By default, EKS clusters have private endpoints. We need to enable public access:

```powershell
# Enable public endpoint
aws eks update-cluster-config --name ai-chatbot-cluster `
    --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true `
    --region ap-southeast-2
```

Then wait 2-3 minutes and:

```powershell
# Update kubeconfig
aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2

# Test
kubectl cluster-info
```

### Option 2: Use AWS VPN/Private Network (Production)

If you want to keep the private endpoint:
- Set up AWS Systems Manager Session Manager
- Use EC2 Instance Connect through bastion host
- Configure VPN access to your VPC

---

## Why Nodes Are Unhealthy

The node health issue is SECONDARY to the DNS problem:

1. Nodes try to register with the cluster API endpoint
2. They also need to reach it (same DNS issue)
3. Because local kubectl can't reach the endpoint either, we can't see the actual node errors
4. Once public endpoint is enabled, the real logs will be visible

---

## Current Architecture Issue

```
Your Local Machine
    ↓
Can't resolve: 0D93D99...eks.amazonaws.com (private AWS DNS)
    ↓
kubectl fails
    ↓
Can't see node logs or status

Nodes (in public subnet with public IPs)
    ↓
Try to register with cluster
    ↓
Can reach private endpoint (they're in AWS)
    ↓  
But something else is wrong → "Unhealthy" status
```

---

## Fix Steps (In Order)

### Step 1: Check Current Endpoint Configuration

```powershell
aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 `
    --query 'cluster.resourcesVpcConfig.[endpointPublicAccess, endpointPrivateAccess]' `
    --output text

# Output should be: True False (or False True)
# We want: True True
```

### Step 2: Enable Public Endpoint

```powershell
Write-Host "Enabling public endpoint..." -ForegroundColor Yellow

aws eks update-cluster-config --name ai-chatbot-cluster `
    --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true `
    --region ap-southeast-2 2>&1

Write-Host "Waiting for update (2-3 minutes)..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Monitor
$status = "UPDATING"
while ($status -eq "UPDATING") {
    $status = aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 `
        --query 'cluster.status' --output text 2>&1
    Write-Host "  Status: $status" -ForegroundColor Gray
    Start-Sleep -Seconds 20
}

Write-Host "Update complete!" -ForegroundColor Green
```

### Step 3: Update kubeconfig

```powershell
Write-Host "Updating kubeconfig..." -ForegroundColor Yellow
aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2 2>&1

Start-Sleep -Seconds 3

Write-Host "Testing connection..." -ForegroundColor Yellow
kubectl cluster-info 2>&1
```

### Step 4: Check Nodes

```powershell
Write-Host "Getting nodes..." -ForegroundColor Yellow
kubectl get nodes -o wide 2>&1

Write-Host "`nGetting node details..." -ForegroundColor Yellow
kubectl describe nodes 2>&1
```

Once you can see the nodes, the actual health issues will become visible in the describe output.

---

## Expected Timeline

1. **Enable public endpoint**: 2-3 minutes
2. **Update kubeconfig & test**: 1 minute
3. **Nodes appear in k ubectl**: Immediate
4. **Nodes become Ready**: 5-10 minutes more  

---

## Command to Run Now

Copy and run this in PowerShell:

```powershell
cd "d:\AI Work\ai-chatbot-devops"

Write-Host "=== EKS Cluster Endpoint Fix ===" -ForegroundColor Green
Write-Host ""

# Enable public endpoint
Write-Host "1. Enabling public endpoint..." -ForegroundColor Yellow
aws eks update-cluster-config --name ai-chatbot-cluster `
    --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true `
    --region ap-southeast-2 | Out-Null

Write-Host "   Initiated (wait 2-3 min...)" -ForegroundColor Cyan

# Monitor
$elapsed = 0
while ($elapsed -lt 300) {
    $status = aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 `
        --query 'cluster.status' --output text 2>&1
    
    if ($status -eq "ACTIVE") {
        Write-Host "   Complete!" -ForegroundColor Green
        break
    }
    
    Write-Host "   [$elapsed/300s] Status: $status" -ForegroundColor Gray
    Start-Sleep -Seconds 15
    $elapsed += 15
}

# Update kubeconfig
Write-Host ""
Write-Host "2. Updating kubeconfig..." -ForegroundColor Yellow
aws eks update-kubeconfig --name ai-chatbot-cluster --region ap-southeast-2 2>&1 | Out-Null
Write-Host "   Done!" -ForegroundColor Green

# Test
Write-Host ""
Write-Host "3. Testing kubectl..." -ForegroundColor Yellow
kubectl cluster-info 2>&1

# Get nodes
Write-Host ""
Write-Host "4. Getting nodes..." -ForegroundColor Yellow
kubectl get nodes -o wide 2>&1

Write-Host ""
Write-Host "=== Fix Complete ===" -ForegroundColor Green
Write-Host "Nodes should transition to Ready within 5-10 minutes" -ForegroundColor Cyan
```

---

## If Public Endpoint Causes Security Concerns

For production, use AWS Systems Manager Session Manager instead:

```powershell
# Install Session Manager
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Then use:
aws ssm start-session --target i-0ea46ae5e15dca61c --region ap-southeast-2
```

---

## Summary

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| kubectl can't connect | Private endpoint DNS unresolvable locally | Enable public endpoint |
| Nodes "Unhealthy" | Can't see logs due to above | Will resolve after endpoint fix |
| Deployment blocked | No kubectl access | Enable endpoint, then deploy |

**Action**: Run the script above to enable public endpoint and get kubectl working again.
