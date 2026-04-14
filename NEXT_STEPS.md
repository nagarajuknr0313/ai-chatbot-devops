# Next Steps - Deployment Verification Plan

**Status:** Awaiting EC2 node provisioning (started 2026-04-14 14:37:09 UTC+05:30)

---

## 🕐 Timeline for Completion

### **Phase 1: Node Provisioning (Current - ~15 minutes total)**
- ⏳ **In Progress:** EC2 instance launch
- **Duration:** 5-10 minutes remaining
- **Verification:** `aws eks describe-nodegroup --cluster-name ai-chatbot-cluster --nodegroup-name ai-chatbot-node-group --region us-east-1 --query 'nodegroup.status'`
- **Expected Output:** `ACTIVE` (vs current `CREATING`)

### **Phase 2: Pod Scheduling (Automatic - 2-5 minutes after node active)**
- **Trigger:** Node becomes ACTIVE
- **Action:** Kubernetes scheduler automatically places pods
- **Verification:** 
  ```bash
  kubectl get pods -n chatbot
  # Watch for transition from Pending → ContainerCreating → Running
  ```
- **Expected Output:**
  ```
  NAME                        READY   STATUS    RESTARTS   AGE
  backend-8fdd886f9-6nh8n     1/1     Running   0          20m
  backend-8fdd886f9-7nmgn     1/1     Running   0          20m
  backend-8fdd886f9-z5sxv     1/1     Running   0          20m
  frontend-7cc4767f78-fbgqc   1/1     Running   0          20m
  frontend-7cc4767f78-k49nm   1/1     Running   0          20m
  postgres-567bb9c559-8mpfk   1/1     Running   0          20m
  ```

### **Phase 3: Service IP Assignment (Automatic - 1-2 minutes after pods running)**
- **Trigger:** All frontend pods running
- **Action:** LoadBalancer service secures public IP
- **Verification:**
  ```bash
  kubectl get svc -n chatbot frontend-service
  ```
- **Expected Output:**
  ```
  NAME               TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
  frontend-service   LoadBalancer   10.100.x.x      192.0.2.x        80:30000/TCP
  ```

### **Phase 4: Application Verification (2-3 minutes after IP assigned)**
- **Health Check 1:** Backend API responsive
  ```bash
  curl -X GET http://<EXTERNAL-IP>/api/health
  # Expected: 200 OK with health status
  ```
- **Health Check 2:** Database connected
  ```bash
  kubectl logs deployment/backend -n chatbot | grep "database\|connected"
  ```
- **Health Check 3:** Frontend accessible
  ```bash
  curl http://<EXTERNAL-IP>
  # Expected: HTML response with React app
  ```

---

## ✅ Automated Verification Checklist

Run these at each phase to track progress:

### Every 2 minutes while EC2 launching:
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name ai-chatbot-cluster \
  --nodegroup-name ai-chatbot-node-group \
  --region us-east-1 \
  --query 'nodegroup.[status,scalingConfig.desiredSize,resources[0].autoScalingGroups[0].desiredCapacity]'
```

### Once node ACTIVE:
```bash
# Check pod status
kubectl get pods -n chatbot -o wide
# Look for: READY=1/1, STATUS=Running, NODE=<assigned>

# Check node capacity
kubectl get nodes -o wide
# Look for: STATUS=Ready, ready=true
```

### Once pods Running:
```bash
# Check services
kubectl get svc -n chatbot
# Look for frontend-service with EXTERNAL-IP

# Check deployment readiness
kubectl get deployment -n chatbot -o wide
# Look for: READY=3/3, 2/2, 1/1
```

---

## 🔍 Debugging Commands (If Issues Arise)

### Node stuck on CREATING:
```bash
# Check AWS EC2 instance
aws ec2 describe-instances \
  --filters "Name=tag-key,Values=eks:nodegroup-name" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress}'

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?Tags[?Key==`eks:nodegroup-name`]]'
```

### Pods still Pending (after node Active):
```bash
# Check pod event logs
kubectl describe pod <pod-name> -n chatbot
# Look for: FailedScheduling, InsufficientResources, etc.

# Check node resources
kubectl describe node <node-name>
# Look for: Allocatable CPU/Memory, ResourceQuotas
```

### Frontend service no LoadBalancer IP:
```bash
# Check service status
kubectl describe svc frontend-service -n chatbot
# Look for: LoadBalancer events, Ingress status

# Check subnet tags (required for LoadBalancer)
aws ec2 describe-subnets \
  --subnet-ids subnet-0892516486dd42563 subnet-01a4349fcdfac40cd \
  --query 'Subnets[].{ID:SubnetId,Tags:Tags}'
```

---

## 📊 Real-time Monitoring

### Use kubectl watch:
```bash
# Watch pods in real-time
watch -n 2 kubectl get pods -n chatbot

# Watch nodes and capacity
watch -n 5 kubectl get nodes -o wide

# Watch services and IPs
watch -n 3 kubectl get svc -n chatbot
```

### Use kubectl port-forward for local testing:
```bash
# Forward backend service to local
kubectl port-forward svc/chatbot-backend 8000:8000 -n chatbot

# Test locally
curl http://localhost:8000/api/health
```

---

## 🎯 Success Criteria

**Deployment is COMPLETE when:**
1. ✅ EKS Node Group status = `ACTIVE`
2. ✅ All 6 pods status = `Running` (1/1 Ready)
3. ✅ Frontend service has `EXTERNAL-IP` assigned
4. ✅ Backend API responds to health checks
5. ✅ Frontend accessible via browser
6. ✅ Database connection logs show success

**Total Expected Time:** 15-25 minutes from node group creation

---

## 📝 Post-Deployment Tasks

Once deployment verified:

1. **Commit Pending Changes:**
   ```bash
   git add backend/app/api/auth.py DEPLOYMENT_STATUS.md
   git commit -m "docs: Add deployment documentation and security fixes"
   git push origin main
   ```

2. **Scale for Production** (Optional):
   ```bash
   # Request AWS quota increase (currently limited to 1 node)
   # Then scale to 3+ nodes:
   kubectl scale deployment backend --replicas=5 -n chatbot
   kubectl scale deployment frontend --replicas=3 -n chatbot
   ```

3. **Monitor Logs:**
   ```bash
   kubectl logs -f deployment/backend -n chatbot
   kubectl logs -f deployment/frontend -n chatbot
   ```

4. **Document Final Status:**
   - Update DEPLOYMENT_STATUS.md with completion time
   - Record LoadBalancer IP for team access
   - Create runbook for future deployments

---

## 🔗 Quick Access Links

- **AWS Console:** https://console.aws.amazon.com
  - Region: us-east-1
  - EKS Cluster: ai-chatbot-cluster
  
- **Jenkins Dashboard:** http://localhost:8080
  - Job: ai-chatbot-pipeline
  
- **GitHub Repository:** https://github.com/[user]/ai-chatbot-devops
  - Branch: main

- **Local Docker:** `docker ps` and `docker images`
