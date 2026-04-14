# Jenkins Automated Setup Script (PowerShell)
# This script automates the Docker access configuration for Jenkins

Write-Output "=========================================="
Write-Output "Jenkins CI/CD Pipeline Setup"
Write-Output "=========================================="
Write-Output ""

# Step 1: Verify Jenkins is running
Write-Output "Step 1: Verifying Jenkins container..."
$jenkinsRunning = docker ps | Select-String "jenkins"
if ($jenkinsRunning) {
    Write-Output "[OK] Jenkins container is running"
} else {
    Write-Output "[ERROR] Jenkins container is NOT running"
    Write-Output "  Please run: docker-compose -f jenkins/docker-compose.yml up -d"
    exit 1
}

Write-Output ""

# Step 2: Get initial password
Write-Output "Step 2: Retrieving Jenkins initial admin password..."
$JENKINS_PASSWORD = docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>$null
if ($JENKINS_PASSWORD) {
    Write-Output "[OK] Initial Admin Password: $JENKINS_PASSWORD"
    Write-Output ""
    Write-Output "   Use this password to unlock Jenkins at http://localhost:8080"
} else {
    Write-Output "[ERROR] Could not retrieve password. Jenkins may still be initializing."
    exit 1
}

Write-Output ""

# Step 3: Configure Docker access
Write-Output "Step 3: Configuring Docker access for Jenkins..."
docker exec -u root jenkins usermod -aG docker jenkins 2>$null
if ($?) {
    Write-Output "[OK] Jenkins user added to docker group"
} else {
    Write-Output "[WARNING] Could not add jenkins to docker group (may require elevated privileges)"
}

Write-Output ""

# Step 4: Verify Docker access
Write-Output "Step 4: Verifying Docker access in Jenkins..."
$DOCKER_TEST = docker exec jenkins docker ps 2>&1
if (($DOCKER_TEST | Select-String "error" -quiet) -or ($DOCKER_TEST | Select-String "permission" -quiet)) {
    Write-Output "[WARNING] Docker access may have issues"
    Write-Output "   Run: docker exec jenkins docker ps"
} else {
    Write-Output "[OK] Docker is accessible from Jenkins"
}

Write-Output ""

# Step 5: Display next steps
Write-Output "Step 5: Next Actions"
Write-Output "=========================================="
Write-Output ""
Write-Output "1. Open Jenkins UI:"
Write-Output "   -> http://localhost:8080"
Write-Output ""
Write-Output "2. Unlock Jenkins:"
Write-Output "   -> Paste initial password: $JENKINS_PASSWORD"
Write-Output ""
Write-Output "3. Install suggested plugins"
Write-Output "   -> Click 'Install suggested plugins'"
Write-Output "   -> Wait 5-10 minutes"
Write-Output ""
Write-Output "4. Create admin user"
Write-Output "   -> Enter username, password, email"
Write-Output ""
Write-Output "5. Additional plugin installation:"
Write-Output "   -> Manage Jenkins -> Manage Plugins"
Write-Output "   -> Search and install: Docker Pipeline, Kubernetes"
Write-Output ""
Write-Output "6. Create Pipeline Job:"
Write-Output "   -> New Item -> Name: 'ai-chatbot-pipeline'"
Write-Output "   -> Select 'Pipeline'"
Write-Output "   -> Definition: 'Pipeline script from SCM'"
Write-Output "   -> SCM: Git"
Write-Output "   -> Repository URL: https://github.com/YOUR_USERNAME/ai-chatbot-devops"
Write-Output "   -> Script Path: Jenkinsfile"
Write-Output ""
Write-Output "7. Trigger Build:"
Write-Output "   -> Click 'Build Now'"
Write-Output "   -> Monitor console output"
Write-Output ""
Write-Output "=========================================="
Write-Output "Jenkins setup in progress. See JENKINS_SETUP_GUIDE.md for detailed instructions."
