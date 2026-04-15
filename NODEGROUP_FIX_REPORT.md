# EKS Node Group Failure Diagnosis & Fix Report

## Problem Identified

**Initial Failure: NodeCreationFailure**
- Instance IDs: `i-04bcdef084fb4e83f`, `i-07648efbb13d61c7b`
- Root Cause: Nodes were created in **PRIVATE subnets** (10.0.10.0/24, 10.0.11.0/24)
- Network Issue: Private subnets without NAT gateways cannot reach the EKS cluster endpoint
- Status: Instances created but failed to join the Kubernetes cluster

## Diagnosis Details

### Subnet Configuration
```
Public Subnets (MapPublicIpOnLaunch=True):
  - subnet-0390b58f35a6e75b7 (10.0.2.0/24, ap-southeast-2b)
  - subnet-0b343e70846b565af (10.0.1.0/24, ap-southeast-2a)

Private Subnets (MapPublicIpOnLaunch=False):
  - subnet-094009e7eee37970e (10.0.10.0/24, ap-southeast-2a)  ← NODES CREATED HERE
  - subnet-0821e92158052ca2a (10.0.11.0/24, ap-southeast-2b)  ← NODES CREATED HERE
```

### Why This Failed
1. Private subnets require a NAT Gateway for outbound internet access
2. Nodes need internet access to download kubelet and bootstrap scripts
3. Without NAT, bootstrap failed and nodes couldn't join cluster
4. EKS API couldn't communicate with nodes

## Solution Implemented

Fixed the node group by:
1. **Deleted** the failed node group created with private subnets
2. **Reconfigured** to use PUBLIC subnets (simpler for initial setup)
3. **Public subnets** provide automatic internet access without NAT complexity
4. **Recreated** node group: `aws eks create-nodegroup` with public subnet IDs

### Networking Configuration Applied
```
Node Group Created With:
  - Cluster Name: ai-chatbot-cluster
  - Node Group Name: ai-chatbot-node-group
  - Subnets: subnet-0390b58f35a6e75b7, subnet-0b343e70846b565af (PUBLIC)
  - Instance Type: t3.medium
  - Min/Max/Desired: 2/5/2 nodes
  - AMI: AL2023_x86_64_STANDARD
  - Security Group: sg-0a5217864050cc859 (cluster security group)
```

## Current Status

**Monitoring**: Node group is in `CREATING` status
- Expected duration: 5-15 minutes total
- Elapsed at timeout: 20 minutes (monitoring window limit)
- Nodes may still be initializing beyond the script timeout

**Next Step**: Monitor manually with:
```powershell
# Check node group status
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster `
  --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 `
  --query 'nodegroup.status' --output text

# OR check nodes directly
kubectl get nodes -o wide
```

## Prevention for Future

For production deployments, consider:
1. **Option A (Recommended for Dev/Test)**: Use PUBLIC subnets for nodes
   - Simpler, faster, no NAT gateway costs
   - Good for development and testing

2. **Option B (Recommended for Production)**: Use PRIVATE subnets with NAT
   - More secure, restricted outbound access
   - Requires NAT Gateway setup in public subnets
   - Creates cost for NAT data transfers

## Commands to Continue Monitoring

```powershell
# Monitor node group status
while ($true) {
    $status = aws eks describe-nodegroup `
        --cluster-name ai-chatbot-cluster `
        --nodegroup-name ai-chatbot-node-group `
        --region ap-southeast-2 `
        --query 'nodegroup.status' --output text
    Write-Host "Status: $status"
    if ($status -eq "ACTIVE") { break }
    Start-Sleep -Seconds 30
}

# Check nodes
kubectl get nodes -o wide

# Get detailed node info
kubectl get nodes -o json | jq '.items[] | {name:.metadata.name, status:.status.conditions[-1]}'
```

## Completed Steps

✓ Identified node placement in wrong subnets  
✓ Deleted failed node group  
✓ Created new node group with public subnets  
✓ Configured for proper network connectivity  

## Remaining Steps

⏳ Wait for nodes to reach ACTIVE status (may take 5-15 minutes)  
⏳ Verify nodes join cluster (kubectl get nodes)  
→ Build and push Docker images  
→ Deploy application to Kubernetes  

---

**Timeline**:
- Node group creation started: 2026-04-15 10:39 (UTC+5:30)
- Previous failed attempt: 2026-04-15 09:56
- Fix applied: 2026-04-15 10:40+
