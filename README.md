# AI Chatbot DevOps System - Complete Production Ready Setup

> A complete guide to building and deploying a production-ready AI chatbot from scratch on Windows.

## 📋 Overview

This project includes:
- **AI Chatbot Frontend** - React + Vite (ChatGPT-like UI)
- **AI Chatbot Backend** - Python FastAPI (REST + WebSocket)
- **Database** - PostgreSQL (Containerized)
- **DevOps** - Docker, Kubernetes, Jenkins, AWS
- **CI/CD Pipeline** - Automated testing and deployment

**Total Setup Time:** ~6 hours (including installation)

---

## 🚀 Quick Start

### For Users Without Any Tools Installed

```powershell
# 1. Read the installation guide
notepad INSTALLATION_GUIDE.md

# 2. Install all tools (takes 30-45 minutes)
# Follow instructions in INSTALLATION_GUIDE.md

# 3. Open new PowerShell and verify installations
.\verify-installation.ps1

# 4. Proceed with project setup (STEP 3 onwards)
```

### For Users With Some Tools Already Installed

```powershell
# Verify what you have
.\verify-installation.ps1

# Install missing tools from INSTALLATION_GUIDE.md

# Then proceed with project setup
```

---

## 📁 Project Structure

```
ai-chatbot-devops/
├── INSTALLATION_GUIDE.md      ← Start here
├── PROJECT_GUIDE.md           ← Step-by-step guide
├── README.md                  ← This file
├── verify-installation.ps1    ← Run to verify tools
├── .env.example               ← Environment variables template
├── docker-compose.yml         ← Local docker setup
│
├── backend/                   ← Python FastAPI application
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── app/
│
├── frontend/                  ← React + Vite application
│   ├── package.json
│   ├── Dockerfile
│   └── src/
│
├── k8s/                       ← Kubernetes manifests
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   └── postgres-deployment.yaml
│
├── jenkins/                   ← Jenkins pipeline
│   └── Jenkinsfile
│
└── scripts/                   ← Helper scripts
```

---

## 📖 Complete Step-by-Step Guide

### **STEP 1: ✅ Install All Tools** (30-45 min)

**What you need:**
- Windows 10/11 Pro or higher
- 8GB+ RAM
- 50GB+ free disk space

**Read:** `INSTALLATION_GUIDE.md` for detailed instructions

Required tools:
- ✅ Git
- ✅ Node.js & npm
- ✅ Python 3.11+
- ✅ Docker Desktop
- ✅ kubectl + minikube
- ✅ AWS CLI

---

### **STEP 2: ✅ Verify Installation** (5 min)

```powershell
cd "d:\AI Work\ai-chatbot-devops"
.\verify-installation.ps1
```

Expected output: All tools ✓ installed

---

### **STEP 3: Prepare Your System** (10 min)

```powershell
# Create project directory
cd "d:\AI Work\ai-chatbot-devops"

# Initialize git
git init
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Create Python virtual environment
python -m venv venv

# Activate virtual environment (PowerShell)
.\venv\Scripts\Activate.ps1

# Create environment file
Copy-Item .env.example .env
# Edit .env with your settings
```

---

### **STEP 4: Build Backend (FastAPI)** (45 min)

Covered in next document: `BACKEND_SETUP.md`

Includes:
- FastAPI application setup
- JWT Authentication
- Chat API endpoints
- WebSocket support
- PostgreSQL integration
- Rate limiting

---

### **STEP 5: Build Frontend (React)** (45 min)

Covered in next document: `FRONTEND_SETUP.md`

Includes:
- React + Vite project
- ChatGPT-like UI
- WebSocket client
- Message streaming
- Authentication
- Styling

---

### **STEP 6: Docker Setup** (30 min)

Covered in next document: `DOCKER_SETUP.md`

Creates:
- Dockerfile for backend
- Dockerfile for frontend
- docker-compose.yml
- nginx configuration

---

### **STEP 7: Run Locally with Docker** (20 min)

```powershell
# Start all services
docker-compose up -d

# Verify services are running
docker-compose ps

# Stop all services
docker-compose down
```

---

### **STEP 8: Kubernetes Setup** (45 min)

Covered in next document: `KUBERNETES_SETUP.md`

Includes:
- Start minikube cluster
- Deploy to Kubernetes
- Configure services
- Setup auto-scaling

---

### **STEP 9: Jenkins CI/CD** (30 min)

Covered in next document: `JENKINS_SETUP.md`

---

### **STEP 10: AWS Deployment** (60 min)

Covered in next document: `AWS_SETUP.md`

---

## 🔧 Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Frontend | React + Vite | 18+ / 4+ |
| Backend | Python FastAPI | 3.11+ / 0.104+ |
| Database | PostgreSQL | 15+ |
| Container | Docker | 24+ |
| Orchestration | Kubernetes | 1.28+ |
| Local K8s | Minikube | Latest |
| CI/CD | Jenkins | 2.4+ |
| Cloud | AWS | Latest |

---

## 💡 Key Concepts

### DevOps Pipeline

```
Developer Code (Git)
    ↓
Jenkins Pipeline
    ↓
Build Docker Images
    ↓
Push to Registry (ECR)
    ↓
Deploy to Kubernetes (EKS)
    ↓
Monitor & Scale
```

### Architecture

```
Internet
    ↓
[Load Balancer]
    ↓
[Kubernetes Cluster]
    ├── Frontend Pods (React)
    ├── Backend Pods (FastAPI)
    └── Database Pod (PostgreSQL)
```

---

## 🔐 Security Features

- ✅ JWT Token Authentication
- ✅ Rate Limiting (100 requests/minute)
- ✅ CORS Configuration
- ✅ Environment Variables (.env)
- ✅ Database Persistence
- ✅ SSL/TLS Ready
- ✅ Kubernetes Network Policies

---

## 📊 Performance Features

- ✅ Auto-scaling (HPA)
- ✅ Load Balancing
- ✅ Health Checks
- ✅ Resource Limits
- ✅ Persistent Storage
- ✅ WebSocket Support

---

## 🧪 Testing

Each component includes:
- Unit tests
- Integration tests
- API endpoint tests
- Load testing setup

---

## 📝 Environment Variables

Create `.env` file:

```env
# Backend
POSTGRES_USER=chatbot
POSTGRES_PASSWORD=securepassword
POSTGRES_DB=chatbot_db
DATABASE_URL=postgresql://chatbot:securepassword@postgres:5432/chatbot_db
SECRET_KEY=your-secret-key-change-this
DEBUG=False
RATE_LIMIT=100/minute

# Frontend
VITE_API_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000/ws

# AWS (for later)
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your-id
ECR_REGISTRY=your-id.dkr.ecr.us-east-1.amazonaws.com
```

---

## ⚠️ Common Issues & Solutions

### Docker not starting
```powershell
# Ensure WSL 2 is installed
wsl --install

# Or reinstall Docker Desktop
```

### Port already in use
```powershell
# Find process using port
netstat -ano | findstr :8000

# Kill process
taskkill /PID <PID> /F
```

### Kubernetes connection refused
```powershell
# Start minikube
minikube start --driver=docker

# Set context
kubectl config use-context minikube
```

### Python venv won't activate
```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then activate
.\venv\Scripts\Activate.ps1
```

---

## 📚 Additional Documents

This README is the overview. For detailed steps:

1. **INSTALLATION_GUIDE.md** - Install all tools ⭐ START HERE
2. **verify-installation.ps1** - Verify installations
3. **PROJECT_GUIDE.md** - Full implementation roadmap
4. **BACKEND_SETUP.md** - FastAPI backend code
5. **FRONTEND_SETUP.md** - React frontend code
6. **DOCKER_SETUP.md** - Docker configuration
7. **KUBERNETES_SETUP.md** - Kubernetes deployment
8. **JENKINS_SETUP.md** - Jenkins CI/CD
9. **AWS_SETUP.md** - AWS deployment

---

## 🎯 Success Checklist

Use this to track your progress:

- [ ] All tools installed and verified
- [ ] Project structure created
- [ ] Backend API working locally
- [ ] Frontend running locally
- [ ] Docker Compose working (all services up)
- [ ] Minikube cluster started
- [ ] Kubernetes deployment successful
- [ ] Jenkins pipeline created
- [ ] CI/CD pipeline working
- [ ] AWS resources created
- [ ] Application deployed to AWS EKS
- [ ] Can access application from browser
- [ ] Auto-scaling verified

---

## ⏱️ Timeline

| Phase | Duration | Difficulty |
|-------|----------|-----------|
| Installation | 45 min | 🟢 Easy |
| Setup & Verification | 5 min | 🟢 Easy |
| Backend Development | 45 min | 🟡 Medium |
| Frontend Development | 45 min | 🟡 Medium |
| Docker Setup | 30 min | 🟡 Medium |
| Local Testing | 20 min | 🟡 Medium |
| Kubernetes Setup | 45 min | 🔴 Hard |
| Jenkins Setup | 30 min | 🔴 Hard |
| CI/CD Configuration | 45 min | 🔴 Hard |
| AWS Deployment | 60 min | 🔴 Hard |
| **TOTAL** | **~6 hours** | — |

---

## 🤝 Support

If you encounter issues:

1. **Check the relevant setup guide** for your current step
2. **Review the troubleshooting section** in that guide
3. **Check Docker/Kubernetes logs:**
   ```powershell
   docker logs <container-id>
   kubectl logs <pod-name>
   ```
4. **Verify connectivity:**
   ```powershell
   docker exec <container> ping postgres
   kubectl describe pod <pod-name>
   ```

---

## 🚀 Next Steps

1. ✅ Your first step: **Read `INSTALLATION_GUIDE.md`**
2. ✅ Install all tools (30-45 minutes)
3. ✅ Run `verify-installation.ps1`
4. ✅ Proceed with STEP 3+ following `PROJECT_GUIDE.md`

---

## 📄 License

This project is provided as-is for educational and personal use.

---

## 🎓 Learning Outcomes

After completing this project, you'll understand:
- ✅ Full-stack development (React + Python)
- ✅ Docker containerization
- ✅ Kubernetes orchestration
- ✅ CI/CD pipelines with Jenkins
- ✅ AWS cloud deployment
- ✅ DevOps best practices
- ✅ Production-ready architecture

---

**Ready to get started?** Open `INSTALLATION_GUIDE.md` now! 🚀

#   W e b h o o k   t e s t   a t   0 4 / 1 6 / 2 0 2 6   0 2 : 0 4 : 4 4  
  
 