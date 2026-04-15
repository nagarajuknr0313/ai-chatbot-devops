# Jenkins in Your AI Chatbot Architecture

## 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOCAL DEVELOPMENT                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Your IDE (VS Code)                                     │   │
│  │  - Write/Edit backend code                              │   │
│  │  - Write/Edit frontend code                             │   │
│  │  - Test locally with Docker Compose                     │   │
│  │  - Commit & Push to GitHub                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GITHUB REPOSITORY                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Code Branches: main, dev, feature/*                    │   │
│  │  - Jenkinsfile (CI/CD pipeline)                         │   │
│  │  - backend/ (FastAPI code)                              │   │
│  │  - frontend/ (React/Vite code)                          │   │
│  │  - Dockerfile (build configurations)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │ WEBHOOK TRIGGERS                     │
│                          ▼                                      │
│         ┌──────────────────────────────────┐                   │
│         │  On Push to 'main' branch        │                   │
│         │  GitHub sends event to Jenkins   │                   │
│         └──────────────────────────────────┘                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│              JENKINS ON EC2 (t3.medium instance)                 │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Jenkins Controller (8080)                             │     │
│  │  ┌──────────────────────────────────────────────────┐  │     │
│  │  │  Pipeline Stages:                               │  │     │
│  │  │  1. Checkout SCM (GitHub)                        │  │     │
│  │  │  2. Build backend Docker image                   │  │     │
│  │  │     └─ Run tests                                 │  │     │
│  │  │  3. Build frontend Docker image                  │  │     │
│  │  │     └─ Compile React/Vite                        │  │     │
│  │  │  4. Push to AWS ECR                              │  │     │
│  │  │     ├─ Login to ECR                              │  │     │
│  │  │     ├─ Tag images with build number              │  │     │
│  │  │     └─ Push to ECR registry                       │  │     │
│  │  │  5. Deploy to EKS cluster                         │  │     │
│  │  │     ├─ Update kubeconfig                          │  │     │
│  │  │     ├─ Restart backend pods                       │  │     │
│  │  │     ├─ Restart frontend pods                      │  │     │
│  │  │     └─ Verify deployment health                  │  │     │
│  │  │  6. Send notifications                            │  │     │
│  │  │     └─ Slack message on success/failure           │  │     │
│  │  └──────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────┘     │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
       ┌─────────────────────────────────────────┐
       │  AWS Elastic Container Registry (ECR)   │
       │  ┌─────────────────────────────────────┐│
       │  │ chatbot-backend:latest              ││
       │  │ - Size: ~520MB                      ││
       │  │ - Built with: Python 3.11, FastAPI ││
       │  └─────────────────────────────────────┘│
       │  ┌─────────────────────────────────────┐│
       │  │ chatbot-frontend:latest             ││
       │  │ - Size: ~200MB                      ││
       │  │ - Built with: Node 18, React/Vite  ││
       │  └─────────────────────────────────────┘│
       └─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│              AWS EKS CLUSTER (ap-southeast-2)                    │
│                  ai-chatbot-cluster                              │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Kubernetes Namespace: chatbot                         │     │
│  │  ┌──────────────────────────────────────────────────┐  │     │
│  │  │  Backend Deployment (3 replicas)                 │  │     │
│  │  │  ├─ Pod 1: backend-689c8f4555-8w9zq              │  │     │
│  │  │  ├─ Pod 2: backend-689c8f4555-pddfq              │  │     │
│  │  │  └─ Pod 3: backend-689c8f4555-tqb9r              │  │     │
│  │  │  Service: backend-nlb (Load Balancer)            │  │     │
│  │  │  Port: 8000 → /api/chat, /api/auth              │  │     │
│  │  └──────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────┐  │     │
│  │  │  Frontend Deployment (2 replicas)                │  │     │
│  │  │  ├─ Pod 1: frontend-bc8d57454-vs5c4              │  │     │
│  │  │  └─ Pod 2: frontend-bc8d57454-zbkfl              │  │     │
│  │  │  Service: frontend-nlb (Load Balancer)           │  │     │
│  │  │  Port: 80 → React SPA                            │  │     │
│  │  └──────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────┐  │     │
│  │  │  PostgreSQL StatefulSet                          │  │     │
│  │  │  └─ Service: postgres-service:5432               │  │     │
│  │  └──────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────┘     │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCERS (AWS ELB)                      │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Frontend LB (NLB)                                     │     │
│  │  http://k8s-chatbot-frontend-46f46601bb-d10a2a...  │     │
│  │  Routes → Frontend pods (React app)                   │     │
│  └────────────────────────────────────────────────────────┘     │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Backend LB (NLB)                                      │     │
│  │  http://k8s-chatbot-backendn-28c871c98c-03a3...    │     │
│  │  Routes → Backend pods (FastAPI server)              │     │
│  └────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                    CLIENT BROWSERS                               │
│  https://your-domain.com →  Frontend app (React)                │
│  Makes API calls to backend → FastAPI endpoints                 │
└──────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Complete Deployment Pipeline

### **What Happens When You Push Code?**

```
1. Developer pushes to GitHub (git push)
   └─ Timestamp: T+0 seconds

2. GitHub webhook triggers Jenkins
   └─ Timestamp: T+1 second

3. Jenkins receives event
   └─ Timestamp: T+2 seconds

4. Jenkins runs job:
   
   Stage 1: Checkout
   ├─ Clone repository from GitHub
   ├─ Checkout main branch
   └─ Duration: 5-10 seconds
   
   Stage 2: Build Backend
   ├─ docker build backend/
   ├─ Tag as chatbot-backend:latest
   ├─ Tag as chatbot-backend:123-abc1234
   └─ Duration: 30-45 seconds
   
   Stage 3: Build Frontend  
   ├─ docker build frontend/
   ├─ npm install, npm run build
   ├─ Tag as chatbot-frontend:latest
   └─ Duration: 45-60 seconds
   
   Stage 4: Push to ECR
   ├─ aws ecr get-login-password
   ├─ docker login to ECR
   ├─ docker push backend:latest
   ├─ docker push frontend:latest
   └─ Duration: 30-60 seconds
   
   Stage 5: Deploy to EKS
   ├─ aws eks update-kubeconfig
   ├─ kubectl rollout restart deployment/backend
   ├─ kubectl rollout status (wait for ready)
   ├─ kubectl rollout restart deployment/frontend
   ├─ kubectl rollout status (wait for ready)
   └─ Duration: 2-5 minutes
   
   Stage 6: Verify Deployment
   ├─ Check if backend pods are running
   ├─ Check if frontend pods are running
   └─ Duration: 5 seconds
   
   Stage 7: Notify
   ├─ Send Slack message: "✅ Deployment successful!"
   └─ Duration: 1 second

5. Users see new version in browser
   └─ Total Time: ~5-8 minutes from push to live deployment!
```

---

## 🔄 Data Flow

### **Request Flow (User to Backend)**

```
User Browser (HTTP Request)
↓
AWS Load Balancer (frontend-nlb)
↓
Kubernetes Service (frontend-service)
↓
Frontend Pod (React App)
-------User clicks something-------
↓
API Call to Backend (http://backend-service:8000/api/...)
↓
AWS Load Balancer (backend-nlb)
↓
Kubernetes Service (backend-service)
↓
Backend Pod (FastAPI Server)
↓
PostgreSQL Database
↓
Response back through same path
↓
User sees result in browser
```

---

## 📊 Jenkins Pipeline Visualization

```
┌─────────────────────────────────────────────────────────┐
│                    START                                │
│           (GitHub Webhook Event)                        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
         ┌───────────────┐
         │   Checkout    │
         │   (5-10s)     │
         └───────┬───────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
  ┌──────────────┐ ┌──────────────┐
  │Build Backend │ │Build Frontend│
  │  (30-45s)    │ │   (45-60s)   │
  └──────┬───────┘ └──────┬───────┘
         │                 │
         └────────┬────────┘
                  │
                  ▼
         ┌────────────────┐
         │  Push to ECR   │
         │   (30-60s)     │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │Deploy to EKS   │
         │  (2-5 mins)    │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │    Verify      │
         │   (5 secs)     │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │  Notify Slack  │
         │   (1 second)   │
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │   SUCCESS ✅   │
         │~5-8 mins total │
         └────────────────┘
```

---

## 🔐 Credentials & Permissions

### **Jenkins Needs Access To:**

| Service | Credentials | Used For |
|---------|-------------|----------|
| **GitHub** | SSH Key / Token | Clone repository |
| **AWS ECR** | IAM Role / Access Keys | Push Docker images |
| **AWS EKS** | IAM Role / kubectl config | Deploy to cluster |
| **Slack** | Webhook URL | Send notifications |

### **AWS IAM Role for Jenkins**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 📝 Summary Table

| Component | Purpose | Status |
|-----------|---------|--------|
| **Your Code** | Source code | You write it |
| **GitHub** | Central repository | Webhook triggered |
| **Jenkins** | CI/CD orchestrator | Runs pipeline |
| **Docker** | Container images | Builds locally |
| **ECR** | Image registry | Stores images |
| **EKS** | Kubernetes cluster | Runs containers |
| **Load Balancer** | Public access | Routes traffic |
| **Slack** | Notifications | Alerts team |

---

## ✅ Benefits of This Setup

1. **Automated** - No manual "Build Now" clicks
2. **Fast** - 5-8 minutes from push to live
3. **Reliable** - Same steps every time
4. **Visible** - Team sees deployment status
5. **Scalable** - Add more agents/stages easily
6. **Professional** - Industry-standard setup
7. **Cost-effective** - ~$35/month total

---

## 🎯 Next Actions

1. ✅ Review this architecture diagram
2. ⬜ Setup Jenkins on EC2 using `/scripts/setup-jenkins-ec2.sh`
3. ⬜ Configure AWS credentials in Jenkins
4. ⬜ Setup GitHub webhook
5. ⬜ Make a test code push
6. ⬜ Watch automatic deployment to EKS

---

**Your deployment pipeline is becoming professional! 🚀**
