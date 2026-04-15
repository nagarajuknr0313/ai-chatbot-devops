#!/bin/bash

# Jenkins Setup Script for Ubuntu 22.04 LTS
# This script installs Java 21 and Jenkins on Ubuntu

set -e

echo "=========================================="
echo "   Jenkins Setup for Ubuntu 22.04 LTS"
echo "=========================================="
echo ""

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Java 21 (latest stable)
echo ""
echo "☕ Installing Java 21..."
sudo apt-get install -y default-jdk

# Verify Java installation
echo ""
echo "✓ Verifying Java installation..."
java -version

# Add Jenkins repository
echo ""
echo "📚 Adding Jenkins repository..."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
sudo sh -c 'echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list' > /dev/null
sudo apt-get update

# Install Jenkins
echo ""
echo "🚀 Installing Jenkins..."
sudo apt-get install -y jenkins

# Start Jenkins service
echo ""
echo "⚙️  Starting Jenkins service..."
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to initialize
echo ""
echo "⏳ Waiting for Jenkins to initialize (30 seconds)..."
sleep 30

# Get initial admin password
echo ""
echo "🔑 Jenkins Initial Admin Password:"
echo "=========================================="
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "=========================================="

# Get instance IP
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "✅ Jenkins setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Open Jenkins in your browser: http://$INSTANCE_IP:8080"
echo "2. Paste the initial admin password above"
echo "3. Choose 'Install suggested plugins'"
echo "4. Create first admin user"
echo "5. Optional: Configure Jenkins system settings"
echo ""
echo "💡 Jenkins is running on port 8080"
echo "📖 Documentation: https://www.jenkins.io/doc/"
