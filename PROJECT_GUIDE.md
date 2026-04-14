# AI Chatbot DevOps Project - Complete Implementation Guide

## Project Overview

This is a production-ready AI chatbot system with:
- **Frontend:** React + Vite (ChatGPT-like UI)
- **Backend:** Python FastAPI (REST + WebSocket)
- **Database:** PostgreSQL (Docker)
- **DevOps:** Docker, Kubernetes, Jenkins, AWS
- **CI/CD:** Automated deployment pipeline

---

## Expected Project Structure

After completing all steps:

```
ai-chatbot-devops/
├── INSTALLATION_GUIDE.md          # This file you just read
├── PROJECT_GUIDE.md               # (this file)
├── README.md                       # Project documentation
│
├── backend/                        # FastAPI application
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── app/
│   │   ├── __init__.py
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py
│   │   │   └── chat.py
│   │   ├── models/
│   │   │   └── __init__.py
│   │   ├── config.py
│   │   └── database.py
│   └── tests/
│       └── test_api.py
│
├── frontend/                       # React + Vite application
│   ├── package.json
│   ├── vite.config.js
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── src/
│   │   ├── main.jsx
│   │   ├── App.jsx
│   │   ├── components/
│   │   │   ├── ChatWindow.jsx
│   │   │   ├── MessageInput.jsx
│   │   │   └── MessageList.jsx
│   │   ├── hooks/
│   │   │   └── useChat.js
│   │   └── styles/
│   │       └── App.css
│   └── index.html
│
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── postgres-pvc.yaml
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── configmap.yaml
│
├── jenkins/                        # Jenkins setup
│   ├── Dockerfile
│   ├── Jenkinsfile
│   └── plugins.txt
│
├── docker-compose.yml              # Local Docker setup
├── .env.example                    # Environment template
├── .gitignore
└── scripts/                        # Helper scripts
    ├── setup-local.sh
    ├── setup-minikube.sh
    ├── setup-aws.sh
    └── deploy-to-aws.sh

```

---

## Technology Stack Summary

| Layer | Technology | Version |
|-------|-----------|---------|
| **Frontend** | React | 18+ |
| | Vite | 4+ |
| | Node.js | 18+ |
| **Backend** | Python | 3.11+ |
| | FastAPI | 0.104+ |
| | Pydantic | 2+ |
| | SQLAlchemy | 2+ |
| **Database** | PostgreSQL | 15+ |
| **Container** | Docker | 24+ |
| **Orchestration** | Kubernetes | 1.28+ |
| | Minikube | Latest |
| **CI/CD** | Jenkins | 2.4+ |
| **Cloud** | AWS (EKS/ECR) | Latest |

---

## Prerequisites Checklist

Before starting, verify you have:

- [ ] Windows 10/11 Pro or higher
- [ ] 8GB+ RAM (16GB recommended)
- [ ] 50GB+ free disk space
- [ ] Admin access for software installation
- [ ] Internet connection (for downloads and AWS)
- [ ] AWS account (free tier eligible)

---

## Installation Summary

### Quick Start (If you already have some tools):

```powershell
# Navigate to your workspace
cd "d:\AI Work\ai-chatbot-devops"

# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Verify all installations
Write-Host "Git:" ; git --version
Write-Host "Node:" ; node --version
Write-Host "Python:" ; python --version
Write-Host "Docker:" ; docker --version
Write-Host "kubectl:" ; kubectl version --client
Write-Host "AWS:" ; aws --version
```

---

## Step-by-Step Implementation Roadmap

### **STEP 1: Installation** (30-45 minutes)
see `INSTALLATION_GUIDE.md`
- Install Git, Node.js, Python, Docker, kubectl, minikube, AWS CLI
- Verify all installations

### **STEP 2: Verification** (5 minutes)
- Run verification script
- Test Docker and kubectl
- Confirm all tools working

### **STEP 3: Project Structure** (10 minutes)
- Create directory structure
- Initialize Git repository
- Create .env file

### **STEP 4: Backend (FastAPI)** (45 minutes)
- Create Python virtual environment
- Generate FastAPI application
- Implement authentication (JWT)
- Implement chat endpoint (with mock AI)
- Implement WebSocket support
- Add rate limiting

### **STEP 5: Frontend (React)** (45 minutes)
- Initialize Vite project
- Create ChatGPT-like UI
- Implement WebSocket client
- Add message streaming
- Add authentication

### **STEP 6: Docker Setup** (30 minutes)
- Create Dockerfile for backend
- Create Dockerfile for frontend
- Create docker-compose.yml
- Create nginx.conf for frontend
- Build and test images

### **STEP 7: Local Docker Deployment** (20 minutes)
- Run Docker Compose locally
- Test all services (frontend, backend, postgres)
- Verify communication between services
- Test API endpoints

### **STEP 8: Kubernetes Setup** (45 minutes)
- Start minikube cluster
- Create Kubernetes namespace
- Create deployment manifests for backend/frontend/postgres
- Apply manifests to cluster
- Setup service discovery
- Configure HPA (autoscaling)
- Test pod communication

### **STEP 9: Jenkins Setup** (30 minutes)
- Create Jenkins Dockerfile
- Run Jenkins in Docker
- Configure Jenkins UI
- Install required plugins
- Setup credentials

### **STEP 10: CI/CD Pipeline** (45 minutes)
- Create Jenkinsfile
- Setup pipeline for:
  - Code checkout
  - Testing
  - Docker image build
  - Push to registry
  - Deploy to minikube

### **STEP 11: AWS Deployment** (60 minutes)
- Create ECR repositories
- Create EKS cluster
- Configure AWS IAM roles
- Push Docker images to ECR
- Deploy to EKS
- Configure load balancer
- Setup monitoring

---

## Key Concepts to Understand

### DevOps Pipeline Flow

```
Developer Code (Git) 
    ↓
Jenkins Pull Trigger
    ↓
Build Docker Images
    ↓
Push to Registry (ECR)
    ↓
Deploy to Kubernetes Cluster
    ↓
Running Services
    ↓
Monitor & Scale
```

### Kubernetes Architecture

```
┌─────────────────────────────────────────┐
│      Kubernetes Cluster (Minikube)      │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐  ┌──────────────┐   │
│  │  Frontend    │  │   Backend    │   │
│  │  Pods (3)    │  │   Pods (3)   │   │
│  └──────────────┘  └──────────────┘   │
│        ↑                  ↑             │
│  ┌─────────────┐  ┌──────────────┐   │
│  │ Frontend    │  │  Backend     │   │
│  │ Service     │  │  Service     │   │
│  └─────────────┘  └──────────────┘   │
│                         ↓              │
│                  ┌──────────────┐   │
│                  │  PostgreSQL  │   │
│                  │  Pod         │   │
│                  └──────────────┘   │
│                         ↑             │
│              ┌──────────────────┐   │
│              │  Persistent Vol  │   │
│              │  (Database)      │   │
│              └──────────────────┘   │
│                                     │
│    Ingress / Load Balancer          │
└─────────────────────────────────────┘
        ↑
    Users
```

---

## Environmental Variables

You'll create a `.env` file with:

```
# Backend
DATABASE_URL=postgresql://user:password@postgres:5432/chatbot
SECRET_KEY=your-secret-key-here
DEBUG=False
RATE_LIMIT=100/minute

# Frontend
VITE_API_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000/ws

# AWS (later)
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your-account-id
ECR_REGISTRY=your-account-id.dkr.ecr.us-east-1.amazonaws.com
```

---

## Common Commands Reference

### Docker
```powershell
docker-compose up                      # Start all services
docker-compose down                    # Stop all services
docker build -t name:tag .             # Build image
docker ps                              # List running containers
```

### Kubernetes
```powershell
minikube start                         # Start cluster
kubectl apply -f file.yaml             # Deploy manifest
kubectl get pods                       # List pods
kubectl logs pod-name                  # View logs
kubectl port-forward service/name 8000:8000  # Port forwarding
```

### Git
```powershell
git add .
git commit -m "message"
git push origin main
```

---

## Estimated Timeline

| Phase | Time | Complexity |
|-------|------|-----------|
| Installation | 45 min | Easy |
| Verification | 5 min | Easy |
| Backend | 45 min | Medium |
| Frontend | 45 min | Medium |
| Docker | 30 min | Medium |
| Local Testing | 20 min | Medium |
| Kubernetes | 45 min | Hard |
| Jenkins | 30 min | Hard |
| CI/CD | 45 min | Hard |
| AWS | 60 min | Hard |
| **TOTAL** | **~6 hours** | — |

---

## Support & Troubleshooting

Each implementation file includes:
- Clear installation steps
- Verification commands
- Common troubleshooting
- Example outputs

If you encounter issues:
1. Check relevant section in implementation guide
2. Review error messages carefully
3. Verify previous steps completed
4. Restart Docker Desktop or minikube if needed
5. Check port conflicts: `netstat -ano | findstr :LISTENING`

---

## Next Steps

1. ✅ Read `INSTALLATION_GUIDE.md` completely
2. ✅ Install all required tools (takes 30-45 min)
3. ✅ Run verification script
4. ✅ Return to this guide for STEP 3

---

**Let's build something great!** 🚀

