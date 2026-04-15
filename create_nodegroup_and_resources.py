#!/usr/bin/env python3
"""
Complete EKS Node Group & Supporting Resources Creation
Waits for cluster to be ACTIVE, then creates node group, ECR repos, and RDS
"""
import boto3
import time
import sys
from datetime import datetime

def wait_for_cluster_active(cluster_name, max_wait=900):
    """Wait for EKS cluster to reach ACTIVE status (up to 15 minutes)"""
    eks_client = boto3.client('eks', region_name='ap-southeast-2')
    start_time = time.time()
    
    print(f"\n⏳ Waiting for cluster '{cluster_name}' to become ACTIVE...")
    print("   (This typically takes 10-15 minutes)")
    print("   Checking every 30 seconds...")
    
    while time.time() - start_time < max_wait:
        try:
            response = eks_client.describe_cluster(name=cluster_name)
            status = response['cluster']['status']
            
            elapsed = int(time.time() - start_time)
            print(f"   [{elapsed}s] Status: {status}")
            
            if status == 'ACTIVE':
                print(f"\n✓ Cluster is ACTIVE!")
                return True
            elif status == 'CREATING':
                time.sleep(30)
            else:
                print(f"\n✗ Cluster status: {status}")
                return False
        except Exception as e:
            print(f"   Error checking cluster: {str(e)}")
            time.sleep(30)
    
    print(f"\n⚠️ Timeout: Cluster did not reach ACTIVE within {max_wait} seconds")
    return False

def create_node_group(cluster_name, nodegroup_name, node_role_arn):
    """Create EKS node group"""
    eks_client = boto3.client('eks', region_name='ap-southeast-2')
    
    print(f"\n Creating Node Group '{nodegroup_name}'...")
    
    try:
        response = eks_client.create_nodegroup(
            clusterName=cluster_name,
            nodegroupName=nodegroup_name,
            subnets=[
                'subnet-0ed90c7bafd163d6d',  # private 1
                'subnet-0df3df51e8322aa9e'   # private 2
            ],
            nodeRole=node_role_arn,
            scalingConfig={
                'minSize': 1,
                'maxSize': 4,
                'desiredSize': 1
            },
            instanceTypes=['t3.medium'],
            tags={'Project': 'AI-Chatbot', 'Environment': 'Production'}
        )
        
        nodegroup = response['nodegroup']
        print(f"✓ Node Group Creation Initiated!")
        print(f"  Node Group Name: {nodegroup['nodegroupName']}")
        print(f"  Instance Type: t3.medium")
        print(f"  Desired Size: 1")
        print(f"  Min/Max: 1/4")
        print(f"  Status: {nodegroup['status']}")
        
        return True
    except Exception as e:
        print(f"✗ Error creating node group: {str(e)}")
        return False

def create_ecr_repo(repo_name):
    """Create ECR repository"""
    ecr_client = boto3.client('ecr', region_name='ap-southeast-2')
    
    print(f"\n Creating ECR Repository '{repo_name}'...")
    
    try:
        response = ecr_client.create_repository(
            repositoryName=repo_name,
            imageScanningConfiguration={'scanOnPush': True},
            tags=[
                {'Key': 'Project', 'Value': 'AI-Chatbot'},
                {'Key': 'Environment', 'Value': 'Production'}
            ]
        )
        
        repo = response['repository']
        print(f"✓ ECR Repository Created!")
        print(f"  Repository: {repo['repositoryName']}")
        print(f"  URI: {repo['repositoryUri']}")
        
        return True
    except ecr_client.exceptions.RepositoryAlreadyExistsException:
        print(f"  (Repository already exists)")
        return True
    except Exception as e:
        print(f"✗ Error creating ECR repository: {str(e)}")
        return False

def create_rds_subnet_group():
    """Create RDS DB subnet group"""
    rds_client = boto3.client('rds', region_name='ap-southeast-2')
    
    print(f"\n Creating RDS Subnet Group...")
    
    try:
        response = rds_client.create_db_subnet_group(
            DBSubnetGroupName='ai-chatbot-db-subnet-group',
            DBSubnetGroupDescription='Subnet group for AI Chatbot RDS database',
            SubnetIds=[
                'subnet-0ed90c7bafd163d6d',  # private 1
                'subnet-0df3df51e8322aa9e'   # private 2
            ],
            Tags=[
                {'Key': 'Project', 'Value': 'AI-Chatbot'},
                {'Key': 'Environment', 'Value': 'Production'}
            ]
        )
        
        print(f"✓ RDS Subnet Group Created!")
        print(f"  Group: {response['DBSubnetGroup']['DBSubnetGroupName']}")
        
        return True
    except rds_client.exceptions.DBSubnetGroupAlreadyExistsFault:
        print(f"  (Subnet group already exists)")
        return True
    except Exception as e:
        print(f"✗ Error creating RDS subnet group: {str(e)}")
        return False

def main():
    print("╔════════════════════════════════════════════════════════════════╗")
    print("║        EKS NODE GROUP & SUPPORTING RESOURCES CREATION          ║")
    print("║                  (ap-southeast-2 Region)                       ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    
    cluster_name = 'ai-chatbot-cluster'
    nodegroup_name = 'ai-chatbot-node-group'
    node_role_arn = 'arn:aws:iam::868987408656:role/ai-chatbot-eks-node-group-role'
    
    # Step 1: Wait for cluster to be ACTIVE
    print("\n" + "="*60)
    print("STEP 1: Wait for EKS Cluster to be ACTIVE")
    print("="*60)
    
    if not wait_for_cluster_active(cluster_name):
        print("\n✗ Cluster did not reach ACTIVE status. Exiting.")
        sys.exit(1)
    
    # Step 2: Create Node Group
    print("\n" + "="*60)
    print("STEP 2: Create Node Group")
    print("="*60)
    
    if not create_node_group(cluster_name, nodegroup_name, node_role_arn):
        print("\n⚠️ Node group creation had an issue, but continuing...")
    
    # Step 3: Create ECR Repositories
    print("\n" + "="*60)
    print("STEP 3: Create ECR Repositories")
    print("="*60)
    
    create_ecr_repo('ai-chatbot/backend')
    create_ecr_repo('ai-chatbot/frontend')
    
    # Step 4: Create RDS Subnet Group
    print("\n" + "="*60)
    print("STEP 4: Create RDS Infrastructure")
    print("="*60)
    
    create_rds_subnet_group()
    
    # Final Summary
    print("\n" + "="*60)
    print("✓ DEPLOYMENT INITIALIZATION COMPLETE!")
    print("="*60)
    print("\nNext Steps:")
    print("  1. Wait for Node Group status = ACTIVE")
    print("     aws eks describe-nodegroup --cluster-name ai-chatbot-cluster \\")
    print("       --nodegroup-name ai-chatbot-node-group --region ap-southeast-2")
    print("\n  2. Configure kubectl:")
    print("     aws eks update-kubeconfig --name ai-chatbot-cluster \\")
    print("       --region ap-southeast-2")
    print("\n  3. Create Kubernetes namespace and deploy:")
    print("     kubectl apply -f k8s/namespace.yaml")
    print("     kubectl apply -f k8s/*.yaml")
    print("\n  4. Verify deployments:")
    print("     kubectl get pods -n chatbot")
    print("     kubectl get svc -n chatbot")
    print("\nEstimated Time to Full Deployment: 20-30 minutes")
    print("="*60)

if __name__ == '__main__':
    main()
