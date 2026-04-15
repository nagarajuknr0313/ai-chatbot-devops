#!/usr/bin/env python3
"""
EKS Cluster Creation Script for ap-southeast-2
"""
import boto3
import sys
from datetime import datetime

def create_eks_cluster():
    """Create EKS cluster in ap-southeast-2"""
    try:
        # Initialize EKS client for ap-southeast-2
        eks_client = boto3.client('eks', region_name='ap-southeast-2')
        
        print("╔════════════════════════════════════════════════════════╗")
        print("║        Creating EKS Cluster in ap-southeast-2          ║")
        print("╚════════════════════════════════════════════════════════╝")
        print()
        
        # Create EKS cluster
        print("Creating cluster 'ai-chatbot-cluster'...")
        response = eks_client.create_cluster(
            name='ai-chatbot-cluster',
            version='1.28',
            roleArn='arn:aws:iam::868987408656:role/ai-chatbot-eks-cluster-role',
            resourcesVpcConfig={
                'subnetIds': [
                    'subnet-05eac7d814fe70a92',  # public 1
                    'subnet-01dae599497231b5e',  # public 2
                    'subnet-0ed90c7bafd163d6d',  # private 1
                    'subnet-0df3df51e8322aa9e'   # private 2
                ],
                'securityGroupIds': ['sg-0c39ebce05930ba0f']
            },
            tags={'Project': 'AI-Chatbot', 'Environment': 'Production'}
        )
        
        cluster = response['cluster']
        print("\n✓ EKS Cluster Creation Initiated Successfully!")
        print(f"\n  Cluster Name:    {cluster['name']}")
        print(f"  Kubernetes Ver:  {cluster['version']}")
        print(f"  Status:          {cluster['status']}")
        print(f"  ARN:             {cluster['arn']}")
        print(f"  Created:         {cluster['createdAt']}")
        print(f"\n  VPC ID:          {cluster['resourcesVpcConfig']['vpcId']}")
        print(f"  Subnets:         {len(cluster['resourcesVpcConfig']['subnetIds'])} subnets")
        
        print("\n" + "="*60)
        print("⏳ CLUSTER CREATION IN PROGRESS")
        print("="*60)
        print("\nCluster creation typically takes 10-15 minutes.")
        print("Monitor progress with:")
        print("  aws eks describe-cluster --name ai-chatbot-cluster \\")
        print("      --region ap-southeast-2")
        print("\nOr check status with:")
        print("  aws eks list-clusters --region ap-southeast-2")
        print("="*60)
        
        return True
        
    except boto3.client('eks', region_name='ap-southeast-2').exceptions.ResourceInUseException:
        print("✗ Cluster already exists!")
        return False
    except Exception as e:
        print(f"\n✗ Error creating cluster:")
        print(f"  {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = create_eks_cluster()
    sys.exit(0 if success else 1)
