#!/bin/bash

# Deployment Status Monitoring Script
# Run periodically to track EC2 node provisioning and pod scheduling

set -e

CLUSTER_NAME="ai-chatbot-cluster"
NODE_GROUP_NAME="ai-chatbot-node-group"
REGION="ap-southeast-2"
NAMESPACE="chatbot"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  AI Chatbot Deployment Status Monitor${NC}"
echo -e "${BLUE}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}\n"

# Phase 1: Check Node Group Status
echo -e "${YELLOW}[Phase 1] Node Group Status:${NC}"
NODE_GROUP_STATUS=$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODE_GROUP_NAME" \
  --region "$REGION" \
  --output json)

STATUS=$(echo "$NODE_GROUP_STATUS" | grep -o '"status": "[^"]*' | cut -d'"' -f4)
DESIRED=$(echo "$NODE_GROUP_STATUS" | grep -o '"desiredSize": [0-9]*' | cut -d' ' -f2)
CREATED_AT=$(echo "$NODE_GROUP_STATUS" | grep -o '"createdAt": "[^"]*' | cut -d'"' -f4)

if [ "$STATUS" = "ACTIVE" ]; then
    echo -e "${GREEN}✓ Node Group Status: $STATUS${NC}"
else
    echo -e "${YELLOW}⏳ Node Group Status: $STATUS${NC}"
fi

echo "   Created: $CREATED_AT"
echo "   Desired Size: $DESIRED"

# Calculate elapsed time
CREATED_TIMESTAMP=$(date -d "$CREATED_AT" +%s 2>/dev/null || date +%s)
CURRENT_TIMESTAMP=$(date +%s)
ELAPSED=$((CURRENT_TIMESTAMP - CREATED_TIMESTAMP))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))
echo "   Elapsed Time: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"

echo ""

# Phase 2: Check Pod Status
echo -e "${YELLOW}[Phase 2] Kubernetes Pod Status:${NC}"

POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null || echo '{"items":[]}')
TOTAL_PODS=$(echo "$POD_STATUS" | grep -o '"name":' | wc -l)
RUNNING_PODS=$(echo "$POD_STATUS" | grep -o '"ready": true' | wc -l)
PENDING_PODS=$((TOTAL_PODS - RUNNING_PODS))

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ All pods running: $RUNNING_PODS/$TOTAL_PODS${NC}"
elif [ "$PENDING_PODS" -gt 0 ]; then
    echo -e "${YELLOW}⏳ Pods running: $RUNNING_PODS/$TOTAL_PODS (Pending: $PENDING_PODS)${NC}"
else
    echo -e "${RED}✗ No pods found${NC}"
fi

kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
  awk '{printf "   %-30s %s/%s %-15s %s\n", $1, $2, $3, $4, $7}' || echo "   (kubectl not configured)"

echo ""

# Phase 3: Check Services
echo -e "${YELLOW}[Phase 3] Kubernetes Services:${NC}"

SERVICES=$(kubectl get svc -n "$NAMESPACE" -o json 2>/dev/null || echo '{"items":[]}')
SERVICE_COUNT=$(echo "$SERVICES" | grep -o '"name":' | wc -l)

if [ "$SERVICE_COUNT" -gt 0 ]; then
    kubectl get svc -n "$NAMESPACE" --no-headers 2>/dev/null | \
      awk '{printf "   %-25s %-12s %-15s %s\n", $1, $2, $4, $5}' || echo "   (unable to parse)"
    
    # Check for LoadBalancer IP
    LOADBALANCER_IP=$(kubectl get svc frontend-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$LOADBALANCER_IP" ]; then
        echo -e "   ${GREEN}✓ Frontend IP: $LOADBALANCER_IP${NC}"
    else
        echo -e "   ${YELLOW}⏳ Frontend IP: Pending assignment${NC}"
    fi
else
    echo -e "   ${YELLOW}⏳ No services created yet${NC}"
fi

echo ""

# Phase 4: Check Deployments
echo -e "${YELLOW}[Phase 4] Kubernetes Deployments:${NC}"

DEPLOYMENTS=$(kubectl get deployment -n "$NAMESPACE" -o json 2>/dev/null || echo '{"items":[]}')
DEPLOY_COUNT=$(echo "$DEPLOYMENTS" | grep -o '"name":' | wc -l)

if [ "$DEPLOY_COUNT" -gt 0 ]; then
    kubectl get deployment -n "$NAMESPACE" --no-headers 2>/dev/null | \
      awk '{printf "   %-20s %s/%s %s/%s\n", $1, $2, $3, $4, $5}' || echo "   (unable to parse)"
else
    echo -e "   ${YELLOW}⏳ No deployments found yet${NC}"
fi

echo ""

# Phase 5: Check Nodes
echo -e "${YELLOW}[Phase 5] Kubernetes Nodes:${NC}"

NODES=$(kubectl get nodes -o json 2>/dev/null || echo '{"items":[]}')
NODE_COUNT=$(echo "$NODES" | grep -o '"name":' | wc -l)

if [ "$NODE_COUNT" -gt 0 ]; then
    kubectl get nodes --no-headers 2>/dev/null | \
      awk '{printf "   %-30s %-10s %-10s\n", $1, $2, $5}' || echo "   (unable to parse)"
else
    echo -e "   ${YELLOW}⏳ No worker nodes active yet${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"

# Summary and recommendations
echo -e "${YELLOW}Summary:${NC}"
if [ "$STATUS" = "ACTIVE" ] && [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo -e "${GREEN}✅ Deployment Complete!${NC}"
    echo "   - Node group is ACTIVE"
    echo "   - All pods are running"
    echo "   - Check services for LoadBalancer IP"
elif [ "$STATUS" = "ACTIVE" ] && [ "$PENDING_PODS" -gt 0 ]; then
    echo -e "${YELLOW}🔄 Pods scheduling...${NC}"
    echo "   - Node group is ACTIVE"
    echo "   - Pods are being scheduled"
    echo "   - Check again in 1-2 minutes"
elif [ "$STATUS" = "CREATING" ]; then
    echo -e "${YELLOW}⏳ Still provisioning EC2 instance...${NC}"
    echo "   - Expected time: 5-10 minutes total"
    echo "   - Check again in 2 minutes"
else
    echo -e "${RED}❌ Deployment Error${NC}"
    echo "   - Review AWS console for details"
    echo "   - Check CloudTrail for error logs"
fi

echo ""
echo -e "${BLUE}📋 Next check in 2-3 minutes | Ctrl+C to exit${NC}"

exit 0
