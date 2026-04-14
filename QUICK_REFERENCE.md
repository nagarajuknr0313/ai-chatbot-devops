# Quick Reference - Commands & Shortcuts

## Windows PowerShell Navigation
```powershell
cd "d:\AI Work\ai-chatbot-devops"  # Change to project directory
pwd                                 # Print working directory
ls                                  # List files
mkdir folder-name                   # Create directory
rm file-name                        # Delete file
code .                              # Open in VS Code
```

---

## Python (Backend)

### Virtual Environment
```powershell
python -m venv venv                 # Create virtual environment
.\venv\Scripts\Activate.ps1         # Activate (PowerShell)
.\venv\Scripts\Activate.bat         # Activate (CMD)
deactivate                          # Deactivate

# If activation fails:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\venv\Scripts\Activate.ps1
```

### Package Management
```powershell
pip install -r requirements.txt     # Install from file
pip freeze > requirements.txt       # Generate requirements file
pip list                            # List installed packages
pip search package-name             # Search for package
pip uninstall package-name          # Uninstall package
```

### Running Backend
```powershell
cd backend
python main.py                      # Run directly
uvicorn main:app --reload          # Run with auto-reload
uvicorn main:app --host 0.0.0.0    # Run on all interfaces
```

---

## Node.js / npm (Frontend)

### Project Setup
```powershell
npm init -y                         # Initialize project
npm install                         # Install dependencies
npm install package-name            # Install specific package
npm uninstall package-name          # Uninstall package
npm update                          # Update all packages
npm list                            # List installed packages
```

### Running Frontend
```powershell
cd frontend
npm run dev                         # Start development server
npm run build                       # Build for production
npm run preview                     # Preview production build
npm test                            # Run tests
npm run lint                        # Run linter
```

---

## Git

### Basic Commands
```powershell
git init                            # Initialize repository
git status                          # Check status
git add .                           # Stage all files
git commit -m "message"             # Commit changes
git push origin main               # Push to remote
git pull origin main               # Pull from remote
```

### Branching
```powershell
git branch                          # List local branches
git branch branch-name              # Create new branch
git checkout branch-name            # Switch to branch
git checkout -b branch-name         # Create and switch
git merge branch-name               # Merge branch
git delete branch-name              # Delete branch
```

---

## Docker

### Image Management
```powershell
docker build -t name:tag .          # Build image
docker images                       # List images
docker rmi image-id                 # Remove image
docker tag old-name new-name        # Tag image
docker push registry/name:tag       # Push to registry
docker pull image-name              # Pull from registry
```

### Container Management
```powershell
docker run -d --name container-name image-name  # Run container
docker ps                           # List running containers
docker ps -a                        # List all containers
docker logs container-name          # View logs
docker exec -it container-name bash # Access container shell
docker stop container-name          # Stop container
docker start container-name         # Start container
docker rm container-name            # Remove container
```

### Docker Compose
```powershell
docker-compose up                   # Start services
docker-compose up -d                # Start in background
docker-compose down                 # Stop all services
docker-compose ps                   # List services
docker-compose logs service-name    # View service logs
docker-compose build                # Build images
docker-compose restart service-name # Restart service
```

---

## Kubernetes (kubectl)

### Cluster Management
```powershell
minikube start                      # Start cluster
minikube stop                       # Stop cluster
minikube delete                     # Delete cluster
minikube status                     # Check status
minikube dashboard                  # Open dashboard
kubectl cluster-info                # Get cluster info
```

### Deployment
```powershell
kubectl apply -f file.yaml          # Deploy manifest
kubectl create -f file.yaml         # Create resource
kubectl delete -f file.yaml         # Delete resource
kubectl get deployments             # List deployments
kubectl get pods                    # List pods
kubectl get services                # List services
```

### Debugging
```powershell
kubectl describe pod pod-name       # Get pod details
kubectl logs pod-name               # View pod logs
kubectl logs pod-name -c container  # View container logs
kubectl exec -it pod-name bash      # Access pod shell
kubectl port-forward service/name port:port  # Port forward
kubectl port-forward pod/pod-name port:port  # Pod port forward
```

### Scaling
```powershell
kubectl scale deployment name --replicas=3  # Scale deployment
kubectl autoscale deployment name --min=1 --max=10  # Auto-scale
```

---

## Jenkins

### Access Jenkins
```powershell
# Jenkins running in Docker at:
http://localhost:8080

# Default credentials:
# Username: admin
# Password: admin (or check docker logs)
```

### Common Jenkins Tasks
```powershell
# View Jenkins logs
docker logs jenkins

# Restart Jenkins
docker restart jenkins

# Backup Jenkins home
xcopy jenkins_home jenkins_home_backup /E /I

# Access Jenkins container
docker exec -it jenkins bash
```

---

## AWS CLI

### Configuration
```powershell
aws configure                       # Configure credentials
aws configure --profile profile-name # Configure named profile
aws sts get-caller-identity         # Verify credentials
```

### ECR (Docker Registry)
```powershell
# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin [account-id].dkr.ecr.us-east-1.amazonaws.com

# Tag image for ECR
docker tag local-image:tag [account-id].dkr.ecr.region.amazonaws.com/repo-name:tag

# Push to ECR
docker push [account-id].dkr.ecr.region.amazonaws.com/repo-name:tag
```

### EKS (Kubernetes)
```powershell
# Create cluster
aws eks create-cluster --name cluster-name --version 1.28 --role-arn arn:aws:iam::[account]:role/eks-service-role --resources-vpc-config subnetIds=subnet-xxxxx

# Get credentials
aws eks update-kubeconfig --name cluster-name --region us-east-1

# List clusters
aws eks list-clusters
```

---

## Common Port Numbers

| Service | Port | URL |
|---------|------|-----|
| Frontend (Vite) | 5173 | http://localhost:5173 |
| Frontend (dev) | 3000 | http://localhost:3000 |
| Backend (FastAPI) | 8000 | http://localhost:8000 |
| Backend (docs) | 8000 | http://localhost:8000/docs |
| PostgreSQL | 5432 | localhost:5432 |
| Jenkins | 8080 | http://localhost:8080 |
| Kubernetes API | 6443 | https://localhost:6443 |
| Docker Registry | 5000 | localhost:5000 |

---

## Useful PS1 Scripts

### Check Port Usage
```powershell
# Find what's using port 8000
netstat -ano | findstr :8000

# Kill process using port
taskkill /PID [PID] /F
```

### Check Docker Status
```powershell
# Full health check
Write-Host "Docker:" ; docker --version
Write-Host "Docker daemon:" ; docker info
Write-Host "Images:" ; docker images
Write-Host "Containers:" ; docker ps -a
```

### Check Kubernetes Status
```powershell
# Full cluster check
Write-Host "Minikube:" ; minikube status
Write-Host "Cluster:" ; kubectl cluster-info
Write-Host "Nodes:" ; kubectl get nodes
Write-Host "Pods:" ; kubectl get pods -A
```

---

## Troubleshooting Quick Fixes

### Port Already in Use
```powershell
# Find process using port
netstat -ano | findstr :PORT_NUMBER

# Kill it
taskkill /PID [PID] /F
```

### Docker Commands Failing
```powershell
# Restart Docker Desktop from system tray
# Or:
Restart-Service docker
```

### Kubernetes Connection Issues
```powershell
# Make sure minikube is running
minikube start --driver=docker

# Reset kubectl context
kubectl config use-context minikube

# Full reset (careful!)
minikube delete
minikube start --driver=docker
```

### Python Virtual Environment Issues
```powershell
# Recreate venv
Remove-Item -Recurse venv
python -m venv venv
.\venv\Scripts\Activate.ps1
```

### Permission Denied in PowerShell
```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Accept when prompted
```

---

## File Locations

```powershell
# Project root
d:\AI Work\ai-chatbot-devops\

# Backend code
d:\AI Work\ai-chatbot-devops\backend\

# Frontend code
d:\AI Work\ai-chatbot-devops\frontend\

# Kubernetes manifests
d:\AI Work\ai-chatbot-devops\k8s\

# Jenkins setup
d:\AI Work\ai-chatbot-devops\jenkins\

# Docker configuration
d:\AI Work\ai-chatbot-devops\docker-compose.yml

# Environment variables
d:\AI Work\ai-chatbot-devops\.env
```

---

## Testing Connectivity

### Test Backend
```powershell
# API health check
curl http://localhost:8000/health

# Or in PowerShell
Invoke-WebRequest -Uri http://localhost:8000/health

# With authentication
$headers = @{ "Authorization" = "Bearer $token" }
Invoke-WebRequest -Uri http://localhost:8000/api/chat -Headers $headers
```

### Test WebSocket
```powershell
# Can use web browsers DevTools or specific tools
# Or use Python to test
python -c "import websocket; ws = websocket.create_connection('ws://localhost:8000/ws'); ws.send('test'); print(ws.recv())"
```

### Test Database
```powershell
# From container
docker exec -it postgres-container psql -U chatbot -d chatbot_db -c "SELECT 1"

# Or using local psql if installed
psql -h localhost -U chatbot -d chatbot_db -c "SELECT 1"
```

---

## Performance Monitoring

### Docker
```powershell
docker stats                        # Real-time container stats
docker top container-name           # Process info for container
```

### Kubernetes
```powershell
kubectl top nodes                   # Node resource usage
kubectl top pods                    # Pod resource usage
kubectl get hpa                     # Auto-scaling status
```

---

Save this file for quick reference! 📋

