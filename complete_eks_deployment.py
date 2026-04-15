#!/usr/bin/env python3
"""
Complete EKS Deployment Script
Handles node group creation with proper error recovery and monitoring
"""

import boto3
import time
import sys
import subprocess
import json
from datetime import datetime

AWS_REGION = 'ap-southeast-2'
CLUSTER_NAME = 'ai-chatbot-cluster'
NODEGROUP_NAME = 'ai-chatbot-node-group-final'
NODE_ROLE_ARN = 'arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role'
INSTANCE_PROFILE_ARN = 'arn:aws:iam::868987408656:instance-profile/ai-chatbot-eks-node-group-role'
PRIVATE_SUBNETS = ['subnet-0ed90c7bafd163d6d', 'subnet-0df3df51e8322aa9e']

eks_client = boto3.client('eks', region_name=AWS_REGION)
ec2_client = boto3.client('ec2', region_name=AWS_REGION)
iam_client = boto3.client('iam')

def log(msg, status="INFO"):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    symbols = {"INFO": "ℹ️", "✓": "✓", "✗": "✗", "⏳": "⏳"}
    print(f"[{timestamp}] {symbols.get(status, status)} {msg}")

def cleanup_stuck_nodegroups():
    """Delete any stuck or failed node groups"""
    log("Checking for stuck node groups...", "⏳")
    
    try:
        response = eks_client.list_nodegroups(clusterName=CLUSTER_NAME)
        for ng_name in response.get('nodegroups', []):
            if ng_name in [NODEGROUP_NAME, 'ai-chatbot-node-group', 'ai-chatbot-node-group-v2']:
                ng = eks_client.describe_nodegroup(
                    clusterName=CLUSTER_NAME,
                    nodegroupName=ng_name
                )['nodegroup']
                
                if ng['status'] in ['CREATE_FAILED', 'CREATING']:
                    log(f"Deleting stuck node group: {ng_name}", "⏳")
                    eks_client.delete_nodegroup(
                        clusterName=CLUSTER_NAME,
                        nodegroupName=ng_name
                    )
                    
                    # Wait for deletion
                    wait_count = 0
                    while wait_count < 300:
                        try:
                            ng_status = eks_client.describe_nodegroup(
                                clusterName=CLUSTER_NAME,
                                nodegroupName=ng_name
                            )['nodegroup']['status']
                            if ng_status == 'DELETING':
                                wait_count += 15
                                time.sleep(15)
                            else:
                                wait_count += 15
                                time.sleep(15)
                        except:
                            log(f"Node group {ng_name} deleted", "✓")
                            break
    except Exception as e:
        log(f"Error during cleanup: {str(e)}", "✗")

def verify_instance_profile():
    """Verify instance profile exists and has the role"""
    log("Verifying IAM instance profile...", "⏳")
    
    try:
        profile = iam_client.get_instance_profile(
            InstanceProfileName='ai-chatbot-eks-node-group-role'
        )
        if profile['InstanceProfile']['Roles']:
            log(f"Instance profile ready: {profile['InstanceProfile']['InstanceProfileName']}", "✓")
            return True
        else:
            log("Instance profile exists but has no role, attempting to add...", "⏳")
            iam_client.add_role_to_instance_profile(
                InstanceProfileName='ai-chatbot-eks-node-group-role',
                RoleName='ai-chatbot-eks-node-group-role'
            )
            log("Role added to instance profile", "✓")
            return True
    except iam_client.exceptions.NoSuchEntityException:
        log("Instance profile not found, creating...", "⏳")
        try:
            iam_client.create_instance_profile(
                InstanceProfileName='ai-chatbot-eks-node-group-role'
            )
            iam_client.add_role_to_instance_profile(
                InstanceProfileName='ai-chatbot-eks-node-group-role',
                RoleName='ai-chatbot-eks-node-group-role'
            )
            # Wait a moment for profile to be available
            time.sleep(10)
            log("Instance profile created and role attached", "✓")
            return True
        except Exception as e:
            log(f"Failed to create instance profile: {str(e)}", "✗")
            return False

def verify_security_groups():
    """Verify security group rules for node-to-control-plane communication"""
    log("Verifying security group rules...", "⏳")
    
    try:
        cluster_sg_id = 'sg-0c39ebce05930ba0f'
        node_sg_id = 'sg-02fe282674343b933'
        
        # Check if cluster SG allows traffic from node SG on port 443
        cluster_sgs = ec2_client.describe_security_groups(GroupIds=[cluster_sg_id])['SecurityGroups']
        has_ingress_rule = False
        
        for perm in cluster_sgs[0].get('IpPermissions', []):
            if (perm.get('FromPort') == 443 and perm.get('ToPort') == 443):
                for ug in perm.get('UserIdGroupPairs', []):
                    if ug.get('GroupId') == node_sg_id:
                        has_ingress_rule = True
                        break
        
        if not has_ingress_rule:
            log("Adding ingress rule to cluster SG...", "⏳")
            ec2_client.authorize_security_group_ingress(
                GroupId=cluster_sg_id,
                IpPermissions=[{
                    'IpProtocol': 'tcp',
                    'FromPort': 443,
                    'ToPort': 443,
                    'UserIdGroupPairs': [{'GroupId': node_sg_id}]
                }]
            )
            log("Cluster SG ingress rule added", "✓")
        else:
            log("Cluster SG ingress rule already exists", "✓")
            
        # Check if node SG allows egress to cluster SG on port 443
        node_sgs = ec2_client.describe_security_groups(GroupIds=[node_sg_id])['SecurityGroups']
        has_egress_rule = False
        
        for perm in node_sgs[0].get('IpPermissionsEgress', []):
            if (perm.get('FromPort') == 443 and perm.get('ToPort') == 443):
                for ug in perm.get('UserIdGroupPairs', []):
                    if ug.get('GroupId') == cluster_sg_id:
                        has_egress_rule = True
                        break
        
        if not has_egress_rule:
            log("Adding egress rule to node SG...", "⏳")
            ec2_client.authorize_security_group_egress(
                GroupId=node_sg_id,
                IpPermissions=[{
                    'IpProtocol': 'tcp',
                    'FromPort': 443,
                    'ToPort': 443,
                    'UserIdGroupPairs': [{'GroupId': cluster_sg_id}]
                }]
            )
            log("Node SG egress rule added", "✓")
        else:
            log("Node SG egress rule already exists", "✓")
            
    except Exception as e:
        log(f"Warning: Could not verify all SG rules: {str(e)}", "⏳")

def create_nodegroup():
    """Create the EKS node group"""
    log(f"Creating node group: {NODEGROUP_NAME}...", "⏳")
    
    try:
        response = eks_client.create_nodegroup(
            clusterName=CLUSTER_NAME,
            nodegroupName=NODEGROUP_NAME,
            subnets=PRIVATE_SUBNETS,
            nodeRole=NODE_ROLE_ARN,
            scalingConfig={
                'minSize': 1,
                'maxSize': 4,
                'desiredSize': 1
            },
            instanceTypes=['t3.medium'],
            amiType='AL2_x86_64',
            tags={
                'Project': 'AI-Chatbot',
                'Environment': 'Production'
            }
        )
        
        log(f"Node group creation initiated", "✓")
        log(f"Status: {response['nodegroup']['status']}", "✓")
        return True
    except Exception as e:
        log(f"Error creating node group: {str(e)}", "✗")
        return False

def wait_for_nodegroup_active(max_wait=900):
    """Wait for node group to become ACTIVE"""
    log(f"Waiting for node group to become ACTIVE (max {max_wait}s)...", "⏳")
    
    elapsed = 0
    check_interval = 30
    
    while elapsed < max_wait:
        try:
            ng = eks_client.describe_nodegroup(
                clusterName=CLUSTER_NAME,
                nodegroupName=NODEGROUP_NAME
            )['nodegroup']
            
            status = ng['status']
            log(f"[{elapsed}s] Node group status: {status}", "⏳")
            
            if status == 'ACTIVE':
                log(f"Node group is ACTIVE!", "✓")
                return True
            elif status == 'CREATE_FAILED':
                issues = ng.get('health', {}).get('issues', [])
                for issue in issues:
                    log(f"Issue: {issue.get('code')} - {issue.get('message')}", "✗")
                return False
            
            elapsed += check_interval
            time.sleep(check_interval)
            
        except Exception as e:
            log(f"Error checking node group status: {str(e)}", "✗")
            elapsed += check_interval
            time.sleep(check_interval)
    
    log(f"Node group creation timed out after {max_wait}s", "✗")
    return False

def configure_kubectl():
    """Configure kubectl to access the cluster"""
    log("Configuring kubectl...", "⏳")
    
    try:
        cmd = [
            'aws', 'eks', 'update-kubeconfig',
            '--name', CLUSTER_NAME,
            '--region', AWS_REGION
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            log("kubectl configured successfully", "✓")
            
            # Verify with kubectl cluster-info
            verify_cmd = ['kubectl', 'cluster-info']
            verify = subprocess.run(verify_cmd, capture_output=True, text=True)
            
            if verify.returncode == 0:
                log("Kubernetes cluster is accessible", "✓")
                return True
        
        log(f"Error: {result.stderr}", "✗")
        return False
        
    except Exception as e:
        log(f"Error configuring kubectl: {str(e)}", "✗")
        return False

def deploy_kubernetes_resources():
    """Deploy Kubernetes resources (namespace, deployments, services)"""
    log("Deploying Kubernetes resources...", "⏳")
    
    manifest_files = [
        'k8s/namespace.yaml',
        'k8s/backend-deployment.yaml',
        'k8s/frontend-deployment.yaml',
        'k8s/postgres-deployment.yaml'
    ]
    
    for manifest in manifest_files:
        try:
            cmd = ['kubectl', 'apply', '-f', manifest]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                log(f"Deployed: {manifest}", "✓")
            else:
                log(f"Error deploying {manifest}: {result.stderr}", "✗")
                
        except Exception as e:
            log(f"Error deploying {manifest}: {str(e)}", "✗")

def verify_deployment():
    """Verify pods and services are running"""
    log("Verifying deployment...", "⏳")
    
    try:
        # Check pods
        pods_cmd = ['kubectl', 'get', 'pods', '-n', 'chatbot', '-o', 'wide']
        pods_result = subprocess.run(pods_cmd, capture_output=True, text=True)
        
        if pods_result.returncode == 0:
            log("Pods status:", "ℹ️")
            print(pods_result.stdout)
        
        # Check services
        svc_cmd = ['kubectl', 'get', 'svc', '-n', 'chatbot']
        svc_result = subprocess.run(svc_cmd, capture_output=True, text=True)
        
        if svc_result.returncode == 0:
            log("Services status:", "ℹ️")
            print(svc_result.stdout)
        
        # Check nodes
        nodes_cmd = ['kubectl', 'get', 'nodes', '-o', 'wide']
        nodes_result = subprocess.run(nodes_cmd, capture_output=True, text=True)
        
        if nodes_result.returncode == 0:
            log("Cluster nodes:", "ℹ️")
            print(nodes_result.stdout)
            
    except Exception as e:
        log(f"Error verifying deployment: {str(e)}", "✗")

def main():
    print("""
╔════════════════════════════════════════════════════════════════╗
║      COMPLETE EKS DEPLOYMENT WITH RECOVERY                    ║
║           ai-chatbot-cluster Initialization                   ║
╚════════════════════════════════════════════════════════════════╝
    """)
    
    log("Starting EKS deployment process...", "⏳")
    
    # Step 1: Cleanup stuck node groups
    cleanup_stuck_nodegroups()
    
    # Step 2: Verify instance profile
    if not verify_instance_profile():
        log("Failed to setup instance profile", "✗")
        return False
    
    # Step 3: Verify security groups
    verify_security_groups()
    
    # Step 4: Create node group
    if not create_nodegroup():
        log("Failed to create node group", "✗")
        return False
    
    # Step 5: Wait for node group to be ACTIVE
    if not wait_for_nodegroup_active(max_wait=900):
        log("Node group failed to become ACTIVE", "✗")
        # Print detailed status for debugging
        try:
            ng = eks_client.describe_nodegroup(
                clusterName=CLUSTER_NAME,
                nodegroupName=NODEGROUP_NAME
            )['nodegroup']
            log(f"Final nodegroup status: {json.dumps(ng, indent=2, default=str)}", "ℹ️")
        except:
            pass
        return False
    
    # Step 6: Configure kubectl
    if not configure_kubectl():
        log("Failed to configure kubectl", "✗")
        return False
    
    # Step 7: Deploy Kubernetes resources
    log("Deploying Kubernetes resources...", "⏳")
    deploy_kubernetes_resources()
    
    # Step 8: Verify deployment
    log("Final verification...", "⏳")
    time.sleep(5)  # Give pods a moment to start
    verify_deployment()
    
    log("EKS Deployment Complete! 🎉", "✓")
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
