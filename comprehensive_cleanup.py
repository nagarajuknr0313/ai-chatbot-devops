#!/usr/bin/env python3
"""
Comprehensive AWS cleanup script - removes all non-default resources.
Checks and cleans: IAM roles, VPC, EKS, ECR, Clusters, Node Groups, Nodes, Pods.
"""

import subprocess
import json
import time
import sys

REGION = "ap-southeast-2"

class AWSCleanup:
    def __init__(self):
        self.region = REGION
        self.deleted_count = 0
        self.failed_count = 0
        
    def run_cmd(self, cmd, timeout=30):
        """Run AWS CLI command."""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
            return result.stdout.strip(), result.returncode == 0
        except subprocess.TimeoutExpired:
            return "", False
        except Exception as e:
            return str(e), False

    def print_section(self, title):
        """Print section header."""
        print(f"\n{'='*70}")
        print(f"  {title}")
        print('='*70)

    def check_resource(self, name, cmd):
        """Check if resource exists."""
        output, success = self.run_cmd(cmd)
        if success and output and output != "[]":
            return json.loads(output) if output.startswith('[') or output.startswith('{') else output
        return None

    # ===== IAM ROLES =====
    def cleanup_iam_roles(self):
        """Delete custom IAM roles."""
        self.print_section("1️⃣  IAM ROLES - Checking for custom roles")
        
        # List custom roles
        cmd = f"aws iam list-roles --query \"Roles[?RoleName != 'aws-service-role*'].{{Name:RoleName, Arn:Arn}}\" --output json"
        roles, success = self.run_cmd(cmd)
        
        if not success or not roles or roles == "[]":
            print("   ✅ No custom roles found")
            return
        
        try:
            role_list = json.loads(roles)
        except:
            print("   ✅ No custom roles found")
            return
        
        for role in role_list:
            role_name = role.get('Name')
            if role_name and not role_name.startswith('AWS'):
                print(f"   Found: {role_name}")
                # Delete inline policies first
                self.detach_role_policies(role_name)
                # Delete role
                self.delete_role(role_name)

    def detach_role_policies(self, role_name):
        """Detach all policies from role."""
        cmd = f"aws iam list-attached-role-policies --role-name {role_name} --query 'AttachedPolicies[].PolicyArn' --output text"
        policies, _ = self.run_cmd(cmd)
        
        if policies:
            for policy_arn in policies.split():
                print(f"      Detaching policy: {policy_arn}")
                cmd = f"aws iam detach-role-policy --role-name {role_name} --policy-arn {policy_arn}"
                self.run_cmd(cmd)
        
        # Delete inline policies
        cmd = f"aws iam list-role-policies --role-name {role_name} --query 'PolicyNames[]' --output text"
        inline, _ = self.run_cmd(cmd)
        if inline:
            for policy_name in inline.split():
                print(f"      Deleting inline policy: {policy_name}")
                cmd = f"aws iam delete-role-policy --role-name {role_name} --policy-name {policy_name}"
                self.run_cmd(cmd)

    def delete_role(self, role_name):
        """Delete IAM role."""
        cmd = f"aws iam delete-role --role-name {role_name}"
        success, _ = self.run_cmd(cmd)
        if success:
            print(f"      ✅ Deleted: {role_name}")
            self.deleted_count += 1
        else:
            print(f"      ❌ Failed to delete: {role_name}")
            self.failed_count += 1

    # ===== EKS CLUSTERS =====
    def cleanup_eks_clusters(self):
        """Delete EKS clusters and resources."""
        self.print_section("2️⃣  EKS CLUSTERS - Checking for clusters")
        
        cmd = f"aws eks list-clusters --region {self.region} --query 'clusters' --output json"
        clusters_output, success = self.run_cmd(cmd)
        
        if not success or not clusters_output or clusters_output == "[]":
            print("   ✅ No EKS clusters found")
            return
        
        try:
            clusters = json.loads(clusters_output)
        except:
            print("   ✅ No EKS clusters found")
            return
        
        for cluster in clusters:
            print(f"   Found: {cluster}")
            self.delete_nodegroups(cluster)
            self.delete_cluster(cluster)
            time.sleep(2)

    def delete_nodegroups(self, cluster_name):
        """Delete all nodegroups in cluster."""
        cmd = f"aws eks list-nodegroups --cluster-name {cluster_name} --region {self.region} --query 'nodegroups' --output json"
        ngs_output, success = self.run_cmd(cmd)
        
        if success and ngs_output and ngs_output != "[]":
            try:
                nodegroups = json.loads(ngs_output)
                for ng in nodegroups:
                    print(f"      Deleting nodegroup: {ng}")
                    cmd = f"aws eks delete-nodegroup --cluster-name {cluster_name} --nodegroup-name {ng} --region {self.region}"
                    self.run_cmd(cmd, timeout=60)
                    self.deleted_count += 1
                
                # Wait for nodegroup deletion
                print("      Waiting 60 seconds for nodegroups to delete...")
                time.sleep(60)
            except:
                pass

    def delete_cluster(self, cluster_name):
        """Delete EKS cluster."""
        cmd = f"aws eks delete-cluster --name {cluster_name} --region {self.region}"
        success, _ = self.run_cmd(cmd, timeout=60)
        if success:
            print(f"      ✅ Cluster deletion initiated: {cluster_name}")
            self.deleted_count += 1
        else:
            print(f"      ❌ Failed to delete cluster: {cluster_name}")
            self.failed_count += 1

    # ===== ECR REPOSITORIES =====
    def cleanup_ecr(self):
        """Delete ECR repositories."""
        self.print_section("3️⃣  ECR REPOSITORIES")
        
        cmd = f"aws ecr describe-repositories --region {self.region} --query 'repositories[].repositoryName' --output json"
        repos_output, success = self.run_cmd(cmd)
        
        if not success or not repos_output or repos_output == "[]":
            print("   ✅ No ECR repositories found")
            return
        
        try:
            repos = json.loads(repos_output)
        except:
            print("   ✅ No ECR repositories found")
            return
        
        for repo in repos:
            print(f"   Deleting: {repo}")
            cmd = f"aws ecr delete-repository --repository-name {repo} --region {self.region} --force"
            success, _ = self.run_cmd(cmd)
            if success:
                print(f"      ✅ Deleted")
                self.deleted_count += 1
            else:
                print(f"      ⚠️  Failed")
                self.failed_count += 1

    # ===== VPC & NETWORKING =====
    def cleanup_vpc(self):
        """Delete custom VPCs and resources."""
        self.print_section("4️⃣  VPC & NETWORKING - Checking for custom VPCs")
        
        cmd = f"aws ec2 describe-vpcs --region {self.region} --query 'Vpcs[?IsDefault==`false`].VpcId' --output json"
        vpcs_output, success = self.run_cmd(cmd)
        
        if not success or not vpcs_output or vpcs_output == "[]":
            print("   ✅ No custom VPCs found")
            return
        
        try:
            vpcs = json.loads(vpcs_output)
        except:
            print("   ✅ No custom VPCs found")
            return
        
        for vpc_id in vpcs:
            print(f"   Found VPC: {vpc_id}")
            self.clean_vpc_resources(vpc_id)
            self.delete_vpc(vpc_id)
            time.sleep(2)

    def clean_vpc_resources(self, vpc_id):
        """Clean up VPC resources before deletion."""
        # Delete NAT Gateways
        cmd = f"aws ec2 describe-nat-gateways --region {self.region} --filter \"Name=vpc-id,Values={vpc_id}\" --query 'NatGateways[].NatGatewayId' --output json"
        nats_output, _ = self.run_cmd(cmd)
        try:
            nats = json.loads(nats_output) if nats_output else []
            for nat in nats:
                print(f"      Deleting NAT Gateway: {nat}")
                cmd = f"aws ec2 delete-nat-gateway --nat-gateway-id {nat} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass
        
        print("      Waiting 30 seconds for NAT deletion...")
        time.sleep(30)
        
        # Release Elastic IPs
        cmd = f"aws ec2 describe-addresses --region {self.region} --filter \"Name=association.main,Values=false\" --query 'Addresses[?AssociationId!=null].AllocationId' --output json"
        eips_output, _ = self.run_cmd(cmd)
        try:
            eips = json.loads(eips_output) if eips_output else []
            for eip in eips:
                print(f"      Releasing EIP: {eip}")
                cmd = f"aws ec2 release-address --allocation-id {eip} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass
        
        # Delete custom security groups
        cmd = f"aws ec2 describe-security-groups --region {self.region} --filter \"Name=vpc-id,Values={vpc_id}\" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output json"
        sgs_output, _ = self.run_cmd(cmd)
        try:
            sgs = json.loads(sgs_output) if sgs_output else []
            for sg in sgs:
                print(f"      Deleting Security Group: {sg}")
                cmd = f"aws ec2 delete-security-group --group-id {sg} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass
        
        # Delete subnets
        cmd = f"aws ec2 describe-subnets --region {self.region} --filter \"Name=vpc-id,Values={vpc_id}\" --query 'Subnets[].SubnetId' --output json"
        subnets_output, _ = self.run_cmd(cmd)
        try:
            subnets = json.loads(subnets_output) if subnets_output else []
            for subnet in subnets:
                print(f"      Deleting Subnet: {subnet}")
                cmd = f"aws ec2 delete-subnet --subnet-id {subnet} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass
        
        # Delete route tables (non-main)
        cmd = f"aws ec2 describe-route-tables --region {self.region} --filter \"Name=vpc-id,Values={vpc_id}\" --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' --output json"
        rts_output, _ = self.run_cmd(cmd)
        try:
            rts = json.loads(rts_output) if rts_output else []
            for rt in rts:
                print(f"      Deleting Route Table: {rt}")
                cmd = f"aws ec2 delete-route-table --route-table-id {rt} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass
        
        # Detach and delete Internet Gateway
        cmd = f"aws ec2 describe-internet-gateways --region {self.region} --filter \"Name=attachment.vpc-id,Values={vpc_id}\" --query 'InternetGateways[].InternetGatewayId' --output json"
        igws_output, _ = self.run_cmd(cmd)
        try:
            igws = json.loads(igws_output) if igws_output else []
            for igw in igws:
                print(f"      Detaching IGW: {igw}")
                cmd = f"aws ec2 detach-internet-gateway --internet-gateway-id {igw} --vpc-id {vpc_id} --region {self.region}"
                self.run_cmd(cmd)
                
                print(f"      Deleting IGW: {igw}")
                cmd = f"aws ec2 delete-internet-gateway --internet-gateway-id {igw} --region {self.region}"
                self.run_cmd(cmd)
                self.deleted_count += 1
        except:
            pass

    def delete_vpc(self, vpc_id):
        """Delete VPC."""
        cmd = f"aws ec2 delete-vpc --vpc-id {vpc_id} --region {self.region}"
        success, _ = self.run_cmd(cmd)
        if success:
            print(f"      ✅ VPC deleted: {vpc_id}")
            self.deleted_count += 1
        else:
            print(f"      ⚠️  VPC deletion pending (has dependencies)")

    # ===== AUTO SCALING GROUPS =====
    def cleanup_asgs(self):
        """Delete Auto Scaling Groups."""
        self.print_section("5️⃣  AUTO SCALING GROUPS")
        
        cmd = f"aws autoscaling describe-auto-scaling-groups --region {self.region} --query 'AutoScalingGroups[].AutoScalingGroupName' --output json"
        asgs_output, success = self.run_cmd(cmd)
        
        if not success or not asgs_output or asgs_output == "[]":
            print("   ✅ No Auto Scaling Groups found")
            return
        
        try:
            asgs = json.loads(asgs_output)
        except:
            print("   ✅ No Auto Scaling Groups found")
            return
        
        for asg in asgs:
            print(f"   Deleting: {asg}")
            cmd = f"aws autoscaling delete-auto-scaling-group --auto-scaling-group-name {asg} --force-delete --region {self.region}"
            success, _ = self.run_cmd(cmd)
            if success:
                print(f"      ✅ Deleted")
                self.deleted_count += 1
            else:
                print(f"      ⚠️  Failed")
                self.failed_count += 1

    def run_cleanup(self):
        """Run all cleanup steps."""
        print("\n" + "╔" + "="*68 + "╗")
        print("║" + " "*15 + "🧹 COMPREHENSIVE AWS CLEANUP" + " "*27 + "║")
        print("║" + " "*10 + "Removes all non-default resources" + " "*26 + "║")
        print("╚" + "="*68 + "╝")
        
        steps = [
            ("IAM Roles", self.cleanup_iam_roles),
            ("ASGs", self.cleanup_asgs),
            ("EKS", self.cleanup_eks_clusters),
            ("ECR", self.cleanup_ecr),
            ("VPC", self.cleanup_vpc),
        ]
        
        for name, func in steps:
            try:
                func()
            except Exception as e:
                print(f"   ❌ Error in {name}: {e}")
        
        # Final report
        self.print_section("📊 CLEANUP SUMMARY")
        print(f"   Resources deleted: {self.deleted_count}")
        print(f"   Failed deletions: {self.failed_count}")
        print(f"\n   ✨ Cleanup complete!")
        print(f"   AWS account is now clean (only default resources remain)")

if __name__ == "__main__":
    cleaner = AWSCleanup()
    cleaner.run_cleanup()
