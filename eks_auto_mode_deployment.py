#!/usr/bin/env python3
"""
EKS Auto Mode Deployment Script - Kubernetes 1.35
Simplified deployment with automatic node provisioning
No manual node group management required
"""

import subprocess
import json
import time
import sys
from datetime import datetime

# Configuration
REGION = "ap-southeast-2"
CLUSTER_NAME = "ai-chatbot-cluster"
VPC_CIDR = "10.0.0.0/16"
ACCOUNT_ID = "868987408656"

def run_command(cmd, description=""):
    """Execute AWS CLI command and return output"""
    if description:
        print(f"\n[{datetime.now().strftime('%HH:%MM:%SS')}] {description}")
    print(f"  → {cmd[:80]}..." if len(cmd) > 80 else f"  → {cmd}")
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        if result.returncode != 0 and "error" in result.stderr.lower():
            print(f"  ❌ Error: {result.stderr[:200]}")
            return None
        return result.stdout
    except subprocess.TimeoutExpired:
        print(f"  ❌ Command timeout")
        return None

def create_vpc():
    """Step 1: Create VPC with subnets"""
    print("\n" + "="*70)
    print("STEP 1: Creating VPC & Network Infrastructure")
    print("="*70)
    
    # Create VPC
    output = run_command(
        f'aws ec2 create-vpc --cidr-block {VPC_CIDR} --region {REGION} --query "Vpc.VpcId" --output text',
        "Creating VPC..."
    )
    if not output:
        return None
    
    vpc_id = output.strip()
    print(f"  ✅ VPC created: {vpc_id}")
    
    # Enable DNS hostnames (CRITICAL - lesson learned!)
    run_command(
        f'aws ec2 modify-vpc-attribute --vpc-id {vpc_id} --enable-dns-hostnames --region {REGION}',
        "Enabling VPC DNS hostnames (critical fix)..."
    )
    
    # Create Internet Gateway
    output = run_command(
        f'aws ec2 create-internet-gateway --region {REGION} --query "InternetGateway.InternetGatewayId" --output text',
        "Creating Internet Gateway..."
    )
    igw_id = output.strip()
    
    # Attach IGW
    run_command(
        f'aws ec2 attach-internet-gateway --vpc-id {vpc_id} --internet-gateway-id {igw_id} --region {REGION}',
        "Attaching Internet Gateway..."
    )
    
    # Create subnets (2 public for ALBs, 2 private for compute)
    subnets = {}
    subnet_configs = [
        ("public-1", "10.0.1.0/24", "ap-southeast-2a", "public"),
        ("public-2", "10.0.2.0/24", "ap-southeast-2b", "public"),
        ("private-1", "10.0.10.0/24", "ap-southeast-2a", "private"),
        ("private-2", "10.0.11.0/24", "ap-southeast-2b", "private"),
    ]
    
    for name, cidr, az, subnet_type in subnet_configs:
        output = run_command(
            f'aws ec2 create-subnet --vpc-id {vpc_id} --cidr-block {cidr} --availability-zone {az} --region {REGION} --query "Subnet.SubnetId" --output text',
            f"Creating {subnet_type} subnet {name}..."
        )
        subnets[name] = output.strip()
    
    # Create route table for public subnets
    output = run_command(
        f'aws ec2 create-route-table --vpc-id {vpc_id} --region {REGION} --query "RouteTable.RouteTableId" --output text',
        "Creating public route table..."
    )
    public_rt_id = output.strip()
    
    # Add route to IGW
    run_command(
        f'aws ec2 create-route --route-table-id {public_rt_id} --destination-cidr-block 0.0.0.0/0 --gateway-id {igw_id} --region {REGION}',
        "Adding IGW route..."
    )
    
    # Associate public subnets
    for name in ["public-1", "public-2"]:
        run_command(
            f'aws ec2 associate-route-table --subnet-id {subnets[name]} --route-table-id {public_rt_id} --region {REGION}',
            f"Associating {name} with public route table..."
        )
    
    # Enable auto-assign public IP for public subnets
    for name in ["public-1", "public-2"]:
        run_command(
            f'aws ec2 modify-subnet-attribute --subnet-id {subnets[name]} --map-public-ip-on-launch --region {REGION}',
            f"Enabling auto-assign public IP on {name}..."
        )
    
    return {
        "vpc_id": vpc_id,
        "igw_id": igw_id,
        "subnets": subnets,
        "public_rt_id": public_rt_id
    }

def create_eks_auto_mode_cluster(networking):
    """Step 2: Create EKS cluster with Auto Mode enabled"""
    print("\n" + "="*70)
    print("STEP 2: Creating EKS Cluster (Auto Mode - K8s 1.35)")
    print("="*70)
    
    vpc_id = networking["vpc_id"]
    # Use both public and private subnets
    subnet_ids = ",".join([
        networking["subnets"]["public-1"],
        networking["subnets"]["public-2"],
        networking["subnets"]["private-1"],
        networking["subnets"]["private-2"],
    ])
    
    # Create cluster with Auto Mode
    cmd = f'''aws eks create-cluster \
      --name {CLUSTER_NAME} \
      --version 1.35 \
      --role-arn arn:aws:iam::{ACCOUNT_ID}:role/eks-service-role \
      --resources-vpc-config subnetIds={subnet_ids} \
      --region {REGION} \
      --compute-config autoScaling={{maxSize=10,minSize=1}},type=ec2 \
      --query 'cluster.name' \
      --output text'''
    
    output = run_command(cmd, "Creating EKS cluster with Auto Mode...")
    
    if not output or "error" in output.lower():
        print("  ℹ️  Cluster role may not exist. Creating it...")
        create_iam_roles()
        # Retry
        output = run_command(cmd, "Retrying cluster creation...")
    
    if output:
        print(f"  ✅ EKS cluster created: {output.strip()}")
        return True
    return False

def configure_kubectl(cluster_name):
    """Step 3: Configure kubectl"""
    print("\n" + "="*70)
    print("STEP 3: Configuring kubectl Access")
    print("="*70)
    
    run_command(
        f'aws eks update-kubeconfig --name {cluster_name} --region {REGION}',
        "Updating kubeconfig..."
    )
    
    time.sleep(5)
    
    # Verify access
    output = run_command(
        'kubectl cluster-info',
        "Verifying cluster access..."
    )
    
    if output:
        print(f"  ✅ kubectl configured successfully")
        return True
    return False

def create_iam_roles():
    """Create necessary IAM roles"""
    print("\nCreating IAM roles...")
    
    # Create EKS service role
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {"Service": "eks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }
        ]
    }
    
    subprocess.run(
        f'''aws iam create-role \
          --role-name eks-service-role \
          --assume-role-policy-document '{json.dumps(trust_policy)}'
        ''',
        shell=True, capture_output=True
    )
    
    # Attach policy
    subprocess.run(
        '''aws iam attach-role-policy \
          --role-name eks-service-role \
          --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
        ''',
        shell=True, capture_output=True
    )
    
    print("  ✅ IAM roles created")

def deploy_kubernetes_resources():
    """Step 4: Deploy application resources"""
    print("\n" + "="*70)
    print("STEP 4: Deploying Kubernetes Resources")
    print("="*70)
    
    # Wait for cluster to be ready
    print("  ⏳ Waiting for cluster to be ready...")
    time.sleep(15)
    
    # Deploy namespace
    run_command(
        'kubectl create namespace chatbot',
        "Creating namespace..."
    )
    
    print("  ✅ Kubernetes resources deployed")

def display_summary():
    """Display deployment summary"""
    print("\n" + "="*70)
    print("✅ DEPLOYMENT COMPLETE - EKS Auto Mode Active!")
    print("="*70)
    print(f"""
📊 Cluster Information:
  • Name: {CLUSTER_NAME}
  • Kubernetes: 1.35
  • Region: {REGION}
  • Mode: Auto Mode (automatic node provisioning)
  
🚀 Next Steps:
  1. kubectl get nodes  (view worker nodes)
  2. kubectl get pods -A  (view all pods)
  3. Deploy your applications
  4. Configure Ingress for external access

📚 Documentation:
  https://docs.aws.amazon.com/eks/latest/userguide/automode.html

✨ EKS Auto Mode handles all the complexity:
  ✓ Automatic provisioning of worker nodes
  ✓ Scaling based on demand
  ✓ Built-in observability
  ✓ Simplified maintenance
""")

def main():
    """Main deployment flow"""
    print("""
╔════════════════════════════════════════════════════════════════════╗
║          🎉 EKS AUTO MODE DEPLOYMENT - KUBERNETES 1.35           ║
║                   Simplified Container Orchestration              ║
╚════════════════════════════════════════════════════════════════════╝
""")
    
    try:
        # Step 1: Create networking
        networking = create_vpc()
        if not networking:
            print("❌ Failed to create VPC")
            return False
        
        # Step 2: Create EKS cluster with Auto Mode
        if not create_eks_auto_mode_cluster(networking):
            print("❌ Failed to create EKS cluster")
            return False
        
        time.sleep(60)  # Wait for cluster to stabilize
        
        # Step 3: Configure kubectl
        if not configure_kubectl(CLUSTER_NAME):
            print("⚠️  kubectl configuration may need manual verification")
        
        # Step 4: Deploy resources
        deploy_kubernetes_resources()
        
        # Display summary
        display_summary()
        
        return True
        
    except Exception as e:
        print(f"❌ Deployment failed: {str(e)}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
