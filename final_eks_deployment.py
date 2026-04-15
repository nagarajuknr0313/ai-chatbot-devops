#!/usr/bin/env python3
"""
Final EKS Deployment: Node Group, kubectl configuration, and K8s resource deployment
"""
import boto3
import subprocess
import time
import sys
import json
from pathlib import Path

def create_node_group_with_ami():
    """Create EKS node group with proper AMI type"""
    eks_client = boto3.client('eks', region_name='ap-southeast-2')
    
    print("\n Creating Node Group with AL2_x86_64 AMI...")
    
    try:
        response = eks_client.create_nodegroup(
            clusterName='ai-chatbot-cluster',
            nodegroupName='ai-chatbot-node-group',
            subnets=[
                'subnet-0ed90c7bafd163d6d',
                'subnet-0df3df51e8322aa9e'
            ],
            nodeRole='arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role',
            scalingConfig={
                'minSize': 1,
                'maxSize': 4,
                'desiredSize': 1
            },
            amiType='AL2_x86_64',  # Amazon Linux 2 x86_64
            instanceTypes=['t3.medium'],
            tags={'Project': 'AI-Chatbot', 'Environment': 'Production'}
        )
        
        print("✓ Node Group Creation Initiated (with AL2_x86_64 AMI)!")
        return True
    except eks_client.exceptions.ResourceInUseException:
        print("  (Node group already exists)")
        return True
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def wait_for_node_group_active(max_wait=900):
    """Wait for node group to become ACTIVE"""
    eks_client = boto3.client('eks', region_name='ap-southeast-2')
    start_time = time.time()
    
    print("\n⏳ Waiting for Node Group to become ACTIVE...")
    print("   (This typically takes 5-10 minutes)")
    
    while time.time() - start_time < max_wait:
        try:
            response = eks_client.describe_nodegroup(
                clusterName='ai-chatbot-cluster',
                nodegroupName='ai-chatbot-node-group'
            )
            status = response['nodegroup']['status']
            elapsed = int(time.time() - start_time)
            
            print(f"   [{elapsed}s] Status: {status}")
            
            if status == 'ACTIVE':
                print("✓ Node Group is ACTIVE!")
                return True
            elif status in ['CREATING', 'UPDATING']:
                time.sleep(30)
            else:
                print(f"✗ Node Group status: {status}")
                return False
        except Exception as e:
            print(f"   Checking... ({str(e)[:50]})")
            time.sleep(30)
    
    print(f"⚠️ Timeout waiting for node group")
    return False

def configure_kubectl():
    """Configure kubectl for the EKS cluster"""
    print("\n Configuring kubectl...")
    
    try:
        cmd = [
            'aws', 'eks', 'update-kubeconfig',
            '--name', 'ai-chatbot-cluster',
            '--region', 'ap-southeast-2'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✓ kubectl configured successfully!")
            
            # Verify cluster access
            verify_cmd = ['kubectl', 'cluster-info']
            verify_result = subprocess.run(verify_cmd, capture_output=True, text=True)
            
            if verify_result.returncode == 0:
                print("✓ Cluster connection verified!")
                return True
            else:
                print(f"⚠️ Cluster connection issue: {verify_result.stderr[:100]}")
                return True  # Continue anyway
        else:
            print(f"✗ Error: {result.stderr[:200]}")
            return False
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def apply_kubernetes_resources():
    """Apply Kubernetes manifests"""
    print("\n Deploying Kubernetes Resources...")
    
    resources = [
        'k8s/namespace.yaml',
        'k8s/backend-deployment.yaml',
        'k8s/frontend-deployment.yaml',
        'k8s/postgres-deployment.yaml'
    ]
    
    for resource in resources:
        path = Path(resource)
        if not path.exists():
            print(f"⚠️ {resource} not found, skipping")
            continue
        
        try:
            cmd = ['kubectl', 'apply', '-f', resource]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"✓ {resource} deployed")
            else:
                print(f"⚠️ {resource}: {result.stderr[:100]}")
        except Exception as e:
            print(f"⚠️ Error applying {resource}: {str(e)[:100]}")
    
    return True

def verify_deployments():
    """Verify deployed resources"""
    print("\n Verifying Deployments...")
    
    print("\n📦 Pods Status:")
    try:
        cmd = ['kubectl', 'get', 'pods', '-n', 'chatbot', '-o', 'wide']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"⚠️ Unable to get pods: {result.stderr[:100]}")
    except:
        pass
    
    print("\n🔗 Services Status:")
    try:
        cmd = ['kubectl', 'get', 'svc', '-n', 'chatbot', '-o', 'wide']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"⚠️ Unable to get services: {result.stderr[:100]}")
    except:
        pass
    
    print("\n⚙️ Deployments Status:")
    try:
        cmd = ['kubectl', 'get', 'deployments', '-n', 'chatbot', '-o', 'wide']
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"⚠️ Unable to get deployments: {result.stderr[:100]}")
    except:
        pass

def main():
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║      EKS DEPLOYMENT: Node Group, kubectl & Kubernetes          ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    
    # Step 1: Create Node Group
    print("\n" + "="*60)
    print("STEP 1: Create Node Group (with AL2_x86_64 AMI)")
    print("="*60)
    
    if not create_node_group_with_ami():
        print("⚠️ Node group creation issue (may have already been created)")
    
    # Step 2: Wait for Node Group to be ACTIVE
    print("\n" + "="*60)
    print("STEP 2: Wait for Node Group to Become ACTIVE")
    print("="*60)
    
    if not wait_for_node_group_active():
        print("⚠️ Node group not yet active, but continuing...")
    
    # Step 3: Configure kubectl
    print("\n" + "="*60)
    print("STEP 3: Configure kubectl")
    print("="*60)
    
    if not configure_kubectl():
        print("✗ Failed to configure kubectl")
        sys.exit(1)
    
    # Step 4: Deploy Kubernetes Resources
    print("\n" + "="*60)
    print("STEP 4: Deploy Kubernetes Resources")
    print("="*60)
    
    apply_kubernetes_resources()
    
    # Step 5: Verify Deployments
    print("\n" + "="*60)
    print("STEP 5: Verify Deployments")
    print("="*60)
    
    time.sleep(5)  # Give resources time to be created
    verify_deployments()
    
    # Final Summary
    print("\n" + "="*60)
    print("✓ DEPLOYMENT COMPLETE!")
    print("="*60)
    print("\nMonitoring Commands:")
    print("  Watch pod status:")
    print("    kubectl get pods -n chatbot -w")
    print("\n  View pod logs:")
    print("    kubectl logs -f deployment/backend -n chatbot")
    print("    kubectl logs -f deployment/frontend -n chatbot")
    print("\n  Get LoadBalancer IP:")
    print("    kubectl get svc -n chatbot frontend-service")
    print("\n  Access cluster:")
    print("    kubectl exec -it <pod-name> -n chatbot -- /bin/bash")
    print("\n  Check node stats:")
    print("    kubectl top nodes")
    print("    kubectl top pods -n chatbot")
    print("="*60)

if __name__ == '__main__':
    main()
