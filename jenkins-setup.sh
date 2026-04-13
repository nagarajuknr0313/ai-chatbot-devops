#!/bin/bash
# Jenkins Automated Setup Script
# This script automates the Docker access configuration for Jenkins

echo "=========================================="
echo "Jenkins CI/CD Pipeline Setup"
echo "=========================================="
echo ""

# Step 1: Verify Jenkins is running
echo "Step 1: Verifying Jenkins container..."
if docker ps | grep -q jenkins; then
    echo "✓ Jenkins container is running"
else
    echo "✗ Jenkins container is NOT running"
    echo "  Please run: docker-compose -f jenkins/docker-compose.yml up -d"
    exit 1
fi

echo ""

# Step 2: Get initial password
echo "Step 2: Retrieving Jenkins initial admin password..."
JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
if [ -n "$JENKINS_PASSWORD" ]; then
    echo "✓ Initial Admin Password: $JENKINS_PASSWORD"
    echo ""
    echo "   Use this password to unlock Jenkins at http://localhost:8080"
else
    echo "✗ Could not retrieve password. Jenkins may still be initializing."
    exit 1
fi

echo ""

# Step 3: Configure Docker access
echo "Step 3: Configuring Docker access for Jenkins..."
docker exec -u root jenkins usermod -aG docker jenkins 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Jenkins user added to docker group"
else
    echo "⚠ Could not add jenkins to docker group (may require elevated privileges)"
fi

echo ""

# Step 4: Verify Docker access
echo "Step 4: Verifying Docker access in Jenkins..."
DOCKER_TEST=$(docker exec jenkins docker ps 2>&1 | grep -i "permission\|error" | wc -l)
if [ $DOCKER_TEST -eq 0 ]; then
    echo "✓ Docker is accessible from Jenkins"
else
    echo "⚠ Docker access may have issues. Run: docker exec jenkins docker ps"
fi

echo ""

# Step 5: Display next steps
echo "Step 5: Next Actions"
echo "=========================================="
echo ""
echo "1. Open Jenkins UI:"
echo "   → http://localhost:8080"
echo ""
echo "2. Unlock Jenkins:"
echo "   → Paste initial password: $JENKINS_PASSWORD"
echo ""
echo "3. Install suggested plugins"
echo "   → Click 'Install suggested plugins'"
echo "   → Wait 5-10 minutes"
echo ""
echo "4. Create admin user"
echo "   → Enter username, password, email"
echo ""
echo "5. Additional plugin installation:"
echo "   → Manage Jenkins → Manage Plugins"
echo "   → Search and install: Docker Pipeline, Kubernetes"
echo ""
echo "6. Create Pipeline Job:"
echo "   → New Item → Name: 'ai-chatbot-pipeline'"
echo "   → Select 'Pipeline'"
echo "   → Definition: 'Pipeline script from SCM'"
echo "   → SCM: Git"
echo "   → Repository URL: <your-github-repo>"
echo "   → Script Path: Jenkinsfile"
echo ""
echo "7. Trigger Build:"
echo "   → Click 'Build Now'"
echo "   → Monitor console output"
echo ""
echo "=========================================="
echo "Jenkins setup in progress. See JENKINS_SETUP_GUIDE.md for detailed instructions."
