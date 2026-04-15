# EKS Node Group Troubleshooting Guide

## Current Status

**Cluster**: ✅ ACTIVE  
**Node Group**: ❌ CREATE_FAILED (second attempt)  
**Root Cause**: Being investigated - likely security group or network rules

---

## What Happened

### Timeline

| Time | Event | Status |
|------|-------|--------|
| 09:56 | First node group created | ❌ CREATE_FAILED |
| 10:00 | Nodes failed to join cluster | 💥 NodeCreationFailure |
| 10:39 | Diagnosed: Private subnets without NAT | 🔍 Root cause identified |
| 10:43 | Second node group created (public subnets) | ❌ CREATE_FAILED after 33 min |
| 11:16 | Second failure logged | 🚨 Investigating... |

### First Failure: Private Subnets Issue
- **Symptom**: Nodes created but couldn't join cluster
- **Cause**: Created in PRIVATE subnets (10.0.10.0/24, 10.0.11.0/24)
- **Why failed**: No NAT Gateway → nodes couldn't reach cluster endpoint
- **Fix applied**: Recreated in PUBLIC subnets

### Second Failure: Unknown (Public Subnets)
- **Symptom**: Would have prevented nodes from joining again
- **Cause**: Being investigated - likely:
  - Security group ingress rules missing
  - Cluster endpoint not accessible to nodes
  - IAM role permissions insufficient
  - EC2 instance bootstrap failure

---

## Diagnostic Steps

### Option 1: Quick Diagnostic (Recommended)

Run the diagnostic script:
```powershell
cd d:\AI Work\ai-chatbot-devops
.\diagnose-nodegroup-issues.ps1
```

This will check:
- ✅ Cluster health and status
- ✅ Security group configuration
- ✅ Subnet setup (public vs private)
- ✅ IAM role permissions
- ✅ Network connectivity

### Option 2: Manual AWS Console Inspection

1. **EKS Dashboard**:
   - Go to AWS Console → EKS
   - Select `ai-chatbot-cluster`
   - Check "Node groups" tab
   - Look for error messages

2. **Security Groups**:
   - Find security group: `eks-cluster-sg-ai-chatbot-cluster-*`
   - Verify ingress rules exist
   - Check if nodes can communicate with cluster

3. **EC2 Instances**:
   - View running instances in ap-southeast-2
   - Check for any instances created by node group
   - Review instance logs/system log for bootstrap errors

### Option 3: CloudWatch Logs

```powershell
# Get cluster logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/ai-chatbot-cluster --region ap-southeast-2

# Watch cluster events
aws logs tail /aws/eks/ai-chatbot-cluster/cluster --follow --region ap-southeast-2
```

---

## Common Issues & Solutions

### Issue 1: Security Group Rules Missing

**Symptom**: Nodes created but can't communicate with control plane  
**Check**: 
```powershell
aws ec2 describe-security-groups --group-ids sg-0a5217864050cc859 --region ap-southeast-2
```

**Fix**: 
```powershell
# Allow nodes to communicate with control plane (port 443)
aws ec2 authorize-security-group-ingress --group-id sg-0a5217864050cc859 \
    --protocol tcp --port 443 --cidr 10.0.0.0/16 --region ap-southeast-2

# Allow all internal communication
aws ec2 authorize-security-group-ingress --group-id sg-0a5217864050cc859 \
    --protocol all --source-group sg-0a5217864050cc859 --region ap-southeast-2
```

### Issue 2: EC2 Instance Type Not Available

**Symptom**: Node group stuck in CREATING or CREATE_FAILED  
**Check**:
```powershell
# List available instance types in region
aws ec2 describe-instance-types --region ap-southeast-2 \
    --filters "Name=instance-type,Values=t3*" \
    --query 'InstanceTypes[*].InstanceType' --output text
```

**Fix**: 
- Try different instance type: `t3.small` instead of `t3.medium`
- Or use `t3a.medium` or `m5.large`

### Issue 3: Cluster Endpoint Not Reachable

**Symptom**: Nodes bootstrap but can't register with cluster  
**Check**:
```powershell
# From a node (SSH into EC2 instance)
curl -k https://<cluster-endpoint>:443

# Check VPC security groups on node
aws ec2 describe-security-groups --region ap-southeast-2 \
    --filters "Name=vpc-id,Values=vpc-0b01101882c5a3e0a" \
    --query 'SecurityGroups[*].[GroupId, GroupName]'
```

**Fix**: 
- Ensure public subnet has route to NAT/IGW
- Verify security group allows egress to cluster

---

## Recovery Path

### Immediate Actions

1. **Run Diagnostic**:
   ```powershell
   .\diagnose-nodegroup-issues.ps1 | Tee-Object -FilePath diagnostic-results.txt
   ```

2. **Document Findings**: Review diagnostic output

3. **Apply Fix** (based on findings):
   - If security group issue: Fix rules manually
   - If instance type unavailable: Use different type
   - If network issue: Check VPC/subnet routing

4. **Retry Node Group Creation**:
   ```powershell
   .\fix-nodegroup-networking.ps1
   ```

### Alternative: Simplify Architecture

If persistent issues, try minimal setup:

```powershell
# Delete everything and start fresh
.\cleanup-eks.ps1

# Deploy minimal cluster
# (recommended: use AWS Console instead of CLI for IAM roles)
aws eks create-nodegroup --cluster-name ai-chatbot-cluster \
    --nodegroup-name nodes-v2 \
    --subnets subnet-0390b58f35a6e75b7 subnet-0b343e70846b565af \
    --node-role arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role \
    --scaling-config minSize=1,maxSize=3,desiredSize=1 \
    --instance-types t3.small \
    --region ap-southeast-2
```

---

## Architecture Reference

### Current Setup

```
VPC: vpc-0b01101882c5a3e0a (10.0.0.0/16)
│
├─ Public Subnets (MapPublicIpOnLaunch=True)
│  ├─ subnet-0b343e70846b565af (10.0.1.0/24, ap-southeast-2a)
│  └─ subnet-0390b58f35a6e75b7 (10.0.2.0/24, ap-southeast-2b)
│   
├─ Private Subnets (MapPublicIpOnLaunch=False)
│  ├─ subnet-094009e7eee37970e (10.0.10.0/24, ap-southeast-2a)
│  └─ subnet-0821e92158052ca2a (10.0.11.0/24, ap-southeast-2b)
│
└─ EKS Cluster
   ├─ Security Group: sg-0a5217864050cc859
   └─ Control Plane: ✅ ACTIVE
```

### Recommended for Development

Use **PUBLIC subnets only** for simplicity:
- ✅ No NAT gateway costs
- ✅ Direct internet access
- ✅ Faster node bootstrap
- ✅ Simpler debugging

```
EKS Cluster
├─ Node Group (PUBLIC subnets)
│  ├─ subnet-0b343e70846b565af (10.0.1.0/24)
│  └─ subnet-0390b58f35a6e75b7 (10.0.2.0/24)
│
└─ t3.medium nodes (or t3.small if unavailable)
   ├─ node-1: 10.0.1.x
   └─ node-2: 10.0.2.x
```

---

## Useful Commands

```powershell
# Get cluster info
aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 \
    --query 'cluster.[name, status, endpoint]' --output table

# Get node group status
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster \
    --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 \
    --query 'nodegroup.[status, health.issues]' --output json

# List nodes
kubectl get nodes -o wide

# Describe node issues
kubectl describe nodes

# Check pods
kubectl get pods -A

# Get cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# View logs
kubectl logs -n kube-system -l component=kubelet --tail=50
```

---

## Next Steps

1. ✅ Run diagnostic: `.\diagnose-nodegroup-issues.ps1`
2. ✅ Review findings and fix identified issues  
3. ✅ Retry node group creation: `.\fix-nodegroup-networking.ps1`
4. ✅ Verify nodes: `kubectl get nodes`
5. ✅ Continue with application deployment

---

**Status**: Awaiting diagnostic results  
**Last Updated**: 2026-04-15 11:20 UTC+5:30  
**Region**: ap-southeast-2 (Sydney)  
**Account**: 868987408656
