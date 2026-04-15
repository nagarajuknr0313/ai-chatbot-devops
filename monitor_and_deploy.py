#!/usr/bin/env python3
"""
Monitor AWS cleanup completion and automatically deploy fresh EKS Auto Mode cluster.
This script waits for all old resources to be deleted, then starts the fresh deployment.
"""

import subprocess
import json
import time
import sys
from datetime import datetime

REGION = "ap-southeast-2"
VPC_CIDR = "10.0.0.0/16"
CHECK_INTERVAL = 30  # Check every 30 seconds
MAX_WAIT_TIME = 1800  # Max 30 minutes wait for cleanup

def run_aws_cmd(cmd):
    """Run AWS CLI command and return output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return result.stdout.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", 1

def check_cleanup_status():
    """Check if AWS cleanup is complete."""
    status = {
        "clusters_exist": False,
        "vpc_exists": False,
        "instances_running": False,
        "clean": False
    }
    
    # Check EKS clusters
    clusters_cmd = f"aws eks list-clusters --region {REGION} --query 'clusters' --output json 2>/dev/null"
    clusters_output, _ = run_aws_cmd(clusters_cmd)
    try:
        clusters = json.loads(clusters_output) if clusters_output else []
        status["clusters_exist"] = len(clusters) > 0
    except:
        status["clusters_exist"] = False
    
    # Check VPC
    vpc_cmd = f"aws ec2 describe-vpcs --filters 'Name=cidr-block,Values={VPC_CIDR}' --region {REGION} --query 'Vpcs[].VpcId' --output json 2>/dev/null"
    vpc_output, _ = run_aws_cmd(vpc_cmd)
    try:
        vpcs = json.loads(vpc_output) if vpc_output else []
        status["vpc_exists"] = len(vpcs) > 0
    except:
        status["vpc_exists"] = False
    
    # Check running instances
    instances_cmd = f"aws ec2 describe-instances --region {REGION} --filters 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].InstanceId' --output json 2>/dev/null"
    instances_output, _ = run_aws_cmd(instances_cmd)
    try:
        instances_data = json.loads(instances_output) if instances_output else []
        instances = [i for sublist in instances_data for i in sublist] if instances_data else []
        status["instances_running"] = len(instances) > 0
    except:
        status["instances_running"] = False
    
    # Overall clean status
    status["clean"] = not (status["clusters_exist"] or status["vpc_exists"] or status["instances_running"])
    
    return status

def print_status(status):
    """Print cleanup status in friendly format."""
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] AWS Cleanup Status:")
    print(f"  • EKS Clusters:        {'❌ DELETING' if status['clusters_exist'] else '✅ DELETED'}")
    print(f"  • VPC (10.0.0.0/16):   {'⚠️  DELETING' if status['vpc_exists'] else '✅ DELETED'}")
    print(f"  • Running Instances:   {'🔴 TERMINATING' if status['instances_running'] else '✅ TERMINATED'}")
    print(f"  • Overall Status:      {'🔄 CLEANING UP' if not status['clean'] else '✨ READY FOR DEPLOYMENT'}")

def monitor_cleanup():
    """Monitor cleanup progress and wait for completion."""
    print("\n" + "="*70)
    print("🔍 MONITORING AWS CLEANUP PROGRESS")
    print("="*70)
    print(f"Region: {REGION}")
    print(f"Check interval: {CHECK_INTERVAL} seconds")
    print(f"Max wait time: {MAX_WAIT_TIME} seconds ({MAX_WAIT_TIME//60} minutes)")
    print("\nWaiting for cleanup to complete...")
    
    start_time = time.time()
    check_count = 0
    
    while True:
        check_count += 1
        status = check_cleanup_status()
        print_status(status)
        
        if status["clean"]:
            print("\n" + "="*70)
            print("✨ CLEANUP COMPLETE! AWS is ready for fresh deployment.")
            print("="*70)
            return True
        
        elapsed = time.time() - start_time
        if elapsed > MAX_WAIT_TIME:
            print("\n" + "="*70)
            print(f"⚠️  TIMEOUT: Waited {MAX_WAIT_TIME} seconds ({MAX_WAIT_TIME//60} minutes)")
            print("Some resources may still be dependencies. Attempting to continue...")
            print("="*70)
            return False
        
        remaining = MAX_WAIT_TIME - elapsed
        print(f"  ⏳ Next check in {CHECK_INTERVAL}s (elapsed: {elapsed/60:.1f}m, remaining: {remaining/60:.1f}m)")
        
        time.sleep(CHECK_INTERVAL)

def deploy_fresh_cluster():
    """Deploy fresh EKS Auto Mode cluster."""
    print("\n" + "="*70)
    print("🚀 STARTING FRESH EKS AUTO MODE DEPLOYMENT")
    print("="*70)
    print("Kubernetes Version: 1.35 (Latest)")
    print("EKS Mode: Auto Mode (No manual node management)")
    print("Region:", REGION)
    print("\nExecuting deployment script...")
    print("-"*70 + "\n")
    
    # Run the deployment script
    cmd = f"python d:\\AI\\ Work\\ai-chatbot-devops\\eks_auto_mode_deployment.py"
    try:
        result = subprocess.run(cmd, shell=True)
        return result.returncode == 0
    except Exception as e:
        print(f"\n❌ Deployment script error: {e}")
        return False

def main():
    """Main function."""
    print("\n" + "╔" + "="*68 + "╗")
    print("║" + " "*15 + "🎯 EKS CLUSTER DEPLOYMENT AUTOMATION" + " "*17 + "║")
    print("╚" + "="*68 + "╝")
    
    # Monitor cleanup
    cleanup_complete = monitor_cleanup()
    
    if not cleanup_complete:
        print("\n⚠️  WARNING: Cleanup may still be in progress.")
        print("Attempting deployment anyway. AWS may still have blocking resources.")
        print("If deployment fails, wait a few minutes and retry.\n")
    
    # Deploy fresh cluster
    deployment_success = deploy_fresh_cluster()
    
    if deployment_success:
        print("\n" + "="*70)
        print("✅ DEPLOYMENT SUCCESSFUL!")
        print("="*70)
        print("Your fresh EKS Auto Mode cluster is being deployed.")
        print("Check AWS console for status or run: aws eks describe-cluster --name ai-chatbot-eks-auto ...")
    else:
        print("\n" + "="*70)
        print("❌ DEPLOYMENT FAILED")
        print("="*70)
        print("Check the output above for errors.")
    
    return 0 if deployment_success else 1

if __name__ == "__main__":
    sys.exit(main())
