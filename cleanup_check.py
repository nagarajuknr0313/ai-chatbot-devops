#!/usr/bin/env python3
"""
Cross-check AWS cleanup status with timeout and retry logic.
"""

import subprocess
import json
import sys
from datetime import datetime

REGION = "ap-southeast-2"
TIMEOUT = 30  # AWS API calls timeout in seconds (increased to handle AWS busy)

def run_aws(cmd, timeout=TIMEOUT):
    """Run AWS CLI command with timeout."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.stdout.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        return "", False
    except Exception as e:
        return str(e), False

def check_resource(name, cmd, check_fn):
    """Check a resource with custom checker function."""
    print(f"  Checking {name}...", end=" ", flush=True)
    output, success = run_aws(cmd, timeout=TIMEOUT)
    
    if success:
        count, status = check_fn(output)
        if count == 0:
            print(f"✅ CLEAN")
            return True
        else:
            print(f"❌ {status}")
            return False
    else:
        print(f"⏳ API timeout (AWS busy)")
        return None  # Unknown state

def parse_clusters(output):
    try:
        data = json.loads(output) if output else {}
        clusters = data.get('clusters', [])
        return len(clusters), ", ".join(clusters) if clusters else "None"
    except:
        return 0, "Parse error"

def parse_instances(output):
    try:
        count = len(output.split()) if output and output.strip() else 0
        return count, f"{count} running"
    except:
        return 0, "Parse error"

def parse_vpc(output):
    try:
        count = len(output.split()) if output and output.strip() else 0
        return count, "10.0.0.0/16 exists" if count > 0 else "Deleted"
    except:
        return 0, "Parse error"

def parse_asgs(output):
    try:
        count = len(output.split()) if output and output.strip() else 0
        return count, f"{count} ASGs" if count > 0 else "None"
    except:
        return 0, "Parse error"

def main():
    print("\n" + "="*70)
    print("🔍  CROSS-CHECK AWS CLEANUP STATUS")
    print("="*70)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Region: {REGION}\n")
    
    checks = [
        ("EKS Clusters",
         f"aws eks list-clusters --region {REGION} --query 'clusters' --output json 2>/dev/null",
         parse_clusters),
        
        ("EC2 Instances (running)",
         f"aws ec2 describe-instances --region {REGION} --filters 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null",
         parse_instances),
        
        ("VPC (10.0.0.0/16)",
         f"aws ec2 describe-vpcs --region {REGION} --filters 'Name=cidr-block,Values=10.0.0.0/16' --query 'Vpcs[].VpcId' --output text 2>/dev/null",
         parse_vpc),
        
        ("Auto Scaling Groups",
         f"aws autoscaling describe-auto-scaling-groups --region {REGION} --query 'AutoScalingGroups[].AutoScalingGroupName' --output text 2>/dev/null",
         parse_asgs),
    ]
    
    results = []
    for name, cmd, parser in checks:
        result = check_resource(name, cmd, parser)
        results.append(result)
    
    # Summary
    print("\n" + "="*70)
    clean = sum(1 for r in results if r is True)
    unknown = sum(1 for r in results if r is None)
    dirty = sum(1 for r in results if r is False)
    
    print(f"SUMMARY: {clean} clean, {dirty} remaining, {unknown} unknown\n")
    
    if dirty == 0 and unknown == 0:
        print("✨ CLEANUP COMPLETE!")
        print("   Ready to deploy fresh EKS Auto Mode cluster.\n")
        return 0
    elif dirty > 0:
        print("⏳ Cleanup still in progress...")
        print("   EKS clusters take 10-15 minutes to delete")
        print("   VPC cleanup takes additional 10-15 minutes\n")
        return 1
    else:
        print("⚠️  AWS API timeout - AWS may be busy")
        print("   Try again in a few moments\n")
        return 2

if __name__ == "__main__":
    sys.exit(main())
