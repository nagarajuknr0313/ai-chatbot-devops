# Complete Installation Guide - Windows DevOps & AI Chatbot Setup

## Overview
This guide covers installation of all required tools for a production-ready AI chatbot with full DevOps setup on Windows.

---

## STEP 1: Install All Required Tools on Windows

### 1.1 Git
**Download:** https://git-scm.com/download/win

**Steps:**
1. Download the latest version (64-bit)
2. Run the installer
3. Accept defaults or choose your preferences
4. When asked about line endings, select "Checkout as-is, commit as-is" (or "Use Windows-style...")
5. Complete installation

**Verify in PowerShell:**
```powershell
git --version
```

---

### 1.2 Node.js & npm
**Download:** https://nodejs.org/en/download/

**Steps:**
1. Download "Current" version (LTS if you prefer stability)
2. Run the installer
3. Accept defaults (includes npm)
4. Choose "Tools for Native Modules" if asked
5. Complete installation

**Verify in PowerShell:**
```powershell
node --version
npm --version
```

---

### 1.3 Python 3.11+
**Download:** https://www.python.org/downloads/

**Steps:**
1. Download Python 3.11 or 3.12 (latest stable)
2. **IMPORTANT:** Check "Add Python to PATH" during installation
3. Check "Install pip"
4. Choose "Customize installation" if needed, ensure:
   - pip is selected
   - Add Python to environment variables
5. Complete installation

**Verify in PowerShell (may need to restart after installation):**
```powershell
python --version
pip --version
```

---

### 1.4 Docker Desktop (Windows)
**Download:** https://www.docker.com/products/docker-desktop

**Requirements:**
- Windows 10/11 Pro, Enterprise, or Education
- WSL 2 (Windows Subsystem for Linux 2)
- Hyper-V enabled

**Steps:**
1. Download Docker Desktop Installer
2. Run installer
3. Allow installation to install WSL 2 if not already present
4. Check "Use WSL 2 based engine" during setup
5. Complete installation (requires restart)
6. Restart your computer
7. Docker will start automatically

**Verify in PowerShell:**
```powershell
docker --version
docker run hello-world
```

---

### 1.5 Minikube (Local Kubernetes)
**Download:** https://minikube.sigs.k8s.io/docs/start/

**Steps via Chocolatey (Recommended):**
```powershell
# If Chocolatey not installed, open PowerShell as Admin first:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Chocolatey
iwr https://community.chocolatey.org/install.ps1 -UseBasicParsing | iex

# Then install minikube
choco install minikube -y

# Also install kubectl
choco install kubernetes-cli -y
```

**Alternative: Manual Installation**
1. Download minikube: https://minikube.sigs.k8s.io/docs/start/
2. Extract to a folder, add to PATH
3. Download kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-on-windows/
4. Extract to a folder, add to PATH

**Verify:**
```powershell
minikube version
kubectl version --client
```

---

### 1.6 AWS CLI v2
**Download:** https://awscli.amazonaws.com/AWSCLIV2.msi

**Steps:**
1. Download the MSI installer
2. Run installer
3. Accept defaults
4. Complete installation (requires restart)
5. Restart PowerShell

**Verify:**
```powershell
aws --version
```

---

### 1.7 Visual Studio Code (Recommended)
**Download:** https://code.visualstudio.com/

**Steps:**
1. Download for Windows
2. Run installer
3. Accept defaults
4. Complete installation

**Recommended Extensions:**
- Python
- Docker
- Kubernetes
- Thunder Client (for API testing)
- REST Client
- Prettier
- ESLint

---

## STEP 2: Verify All Installations

Run all verification commands together:

```powershell
Write-Host "=== System Verification ===" -ForegroundColor Green

Write-Host "`n1. Git:" -ForegroundColor Yellow
git --version

Write-Host "`n2. Node.js:" -ForegroundColor Yellow
node --version

Write-Host "`n3. npm:" -ForegroundColor Yellow
npm --version

Write-Host "`n4. Python:" -ForegroundColor Yellow
python --version

Write-Host "`n5. pip:" -ForegroundColor Yellow
pip --version

Write-Host "`n6. Docker:" -ForegroundColor Yellow
docker --version

Write-Host "`n7. Minikube:" -ForegroundColor Yellow
minikube version

Write-Host "`n8. kubectl:" -ForegroundColor Yellow
kubectl version --client

Write-Host "`n9. AWS CLI:" -ForegroundColor Yellow
aws --version

Write-Host "`n✓ All core tools verified!" -ForegroundColor Green
```

Save this as `verify-installation.ps1` and run:
```powershell
./verify-installation.ps1
```

---

## IMPORTANT: Setting Up Python Virtual Environment

After installing Python, always work in a virtual environment:

```powershell
# Create virtual environment
python -m venv venv

# Activate it (PowerShell)
.\venv\Scripts\Activate.ps1

# If you get execution policy error, run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify activation (you should see (venv) at the start of each line)
python --version
```

---

## IMPORTANT: Docker Configuration

After Docker Desktop installation:

1. **Ensure WSL 2 is running:**
   ```powershell
   wsl --list --verbose
   ```
   You should see a distro with version 2

2. **Test Docker:**
   ```powershell
   docker run hello-world
   ```

3. **Configure to run without `sudo`:**
   Docker Desktop on Windows handles permissions automatically

---

## IMPORTANT: AWS CLI Configuration

After AWS CLI installation, configure credentials:

```powershell
aws configure
```

You'll be prompted for:
- AWS Access Key ID (get from AWS IAM console)
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (use `json`)

---

## Troubleshooting

### Git not recognized:
- Restart PowerShell after installation
- Add Git to PATH manually: `C:\Program Files\Git\cmd`

### Python not found:
- Restart PowerShell/CMD
- Verify "Add Python to PATH" was checked during installation
- Check: `C:\Users\[YourUsername]\AppData\Local\Programs\Python\Python311`

### Docker fails to start:
- Ensure Hyper-V is enabled (Windows Home doesn't support this)
- WSL 2 must be installed: `wsl --install`
- Restart Docker Desktop from system tray

### Minikube won't start:
- Ensure Docker is running first
- Try: `minikube delete` then `minikube start --driver=docker`
- Restart Docker Desktop

### kubectl connection refused:
- Start minikube first: `minikube start`
- Set context: `kubectl config use-context minikube`

---

## Next Steps

Once all tools are installed and verified, proceed to:
- **STEP 3:** Create project structure
- **STEP 4:** Build FastAPI backend
- **STEP 5:** Build React frontend

**Estimated time for installation:** 30-45 minutes
**Estimated total project time:** 3-4 hours

