# EKS Node Group Recovery - AWS Console Recommended Path

## Current Situation

**Node Group Status**: CREATE_FAILED (Unhealthy nodes)  
**Issue**: Nodes failing to join cluster  
**Affected Instances**: i-0ea46ae5e15dca61c, i-0995e17928fdcb9e0

### What We Know
- ✅ VPC created with subnets and IGW
- ✅ Subnets have internet routes (IGW attached)
- ✅ EC2 instances launched with public IPs
- ✅ Security groups configured
- ❌ Nodes not becoming "healthy" in EKS cluster

## Recommended Next Steps

### Option 1: Delete and Try with AWS Console (Recommended for Debugging)

This gives you full visibility into what's happening:

```powershell
# 1. Delete the failed node group
aws eks delete-nodegroup --cluster-name ai-chatbot-cluster `
    --nodegroup-name ai-chatbot-node-group --region ap-southeast-2

# 2. Wait for deletion
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster `
    --nodegroup-name ai-chatbot-node-group --region ap-southeast-2
```

Then in AWS Console:
1. Go to EKS > ai-chatbot-cluster
2. Click "Add node group"
3. Configure with:
   - **Name**: ai-chatbot-node-group
   - **Instance Type**: t3.small 
   - **Subnets**: Select public subnets (10.0.1.0/24, 10.0.2.0/24)
   - **IAM role**: ai-chatbot-eks-node-group-role
   - **Min/Max/Desired**: 2/5/2
4. Review and create
5. Watch the node group creation in real-time in the console
6. See any error messages immediately

### Option 2: Automated Recovery (After Understanding Issue)

Once you identify the root cause in the console, we can:
- Fix the specific issue
- Update the recovery scripts
- Retry programmatically

---

## What Could Be Causing "Unhealthy" Status

1. **CNI Plugin Issue** - Nodes not getting network interfaces
   - Solution: Update VPC CNI plugin

2. **Controller/Addon Issue** - Missing EKS addons
   - Solution: Add EKS control plane addons (coredns, kube-proxy, vpc-cni)

3. **IAM Role Permissions** - Node role missing permissions
   - Solution: Verify IAM policies attached to node role

4. **Bootstrap Error** - Node initialization failed
   - Solution: Check EC2 system logs

5. **Taints/Labels** - Nodes not schedulable
   - Solution: Remove problematic taints

---

## AWS Console Path for Quick Fix

1. **EC2 Dashboard > Instances**
   - Select one instance: i-0ea46ae5e15dca61c
   - Right-click > Monitor and troubleshoot > Get system log
   - Look for kubelet errors or bootstrap issues

2. **EKS Cluster > Resources > Addons**
   - Verify all required addons are installed:
     - amazon-vpc-cni
     - coredns  
     - kube-proxy

3. **CloudWatch > Logs**
   - Group: /aws/eks/ai-chatbot-cluster/cluster
   - Search for error messages from the timestamp when nodes were created

---

## Quick Status Commands

```powershell
# Check node group status
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster `
    --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 `
    --query 'nodegroup.health.issues'

# Check if addons are installed
aws eks list-addons --cluster-name ai-chatbot-cluster --region ap-southeast-2

# Get cluster subnets
aws eks describe-cluster --name ai-chatbot-cluster --region ap-southeast-2 `
    --query 'cluster.resourcesVpcConfig.subnetIds'

# Get node group resource IDs
aws eks describe-nodegroup --cluster-name ai-chatbot-cluster `
    --nodegroup-name ai-chatbot-node-group --region ap-southeast-2 `
    --query 'nodegroup.resources'
```

---

## Next Action

**Recommend**: Visit AWS Console and:
1. Check EC2 instance system logs for bootstrap errors
2. Check if EKS addons are installed properly
3. Look at CloudWatch logs for error messages

Once you identify the specific issue, we can either:
- Fix through AWS Console
- Update scripts to automate the fix
- Try alternate configurations

Would you like me to help you:
- Delete the node group and restart fresh?
- Check specific AWS resources for errors?
- Try installing missing EKS addons?
