#!/bin/bash
set -e

echo "=========================================="
echo "Installing Java 17 and Jenkins"
echo "=========================================="
echo ""

# Step 1: Remove old Jenkins
echo "Step 1: Removing old Jenkins installation..."
sudo systemctl stop jenkins || true
sudo yum remove -y jenkins || true
sudo rm -rf /var/lib/jenkins /var/cache/jenkins

# Step 2: Install Java 17 from Adoptium
echo "Step 2: Installing Java 17 from Adoptium..."
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo rpm --import -
sudo yum install -y java-17-temurin-devel

# Step 3: Verify Java
echo "Step 3: Verifying Java 17..."
java -version

# Step 4: Set Java 17 as default
echo "Step 4: Setting Java 17 as default..."
sudo alternatives --install /usr/bin/java java /usr/lib/jvm/temurin-17-jdk/bin/java 1
java -version

# Step 5: Install Jenkins
echo "Step 5: Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins

# Step 6: Start Jenkins
echo "Step 6: Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Step 7: Wait for Jenkins to start
echo "Step 7: Waiting for Jenkins to start (30 seconds)..."
sleep 30

# Step 8: Check status
echo "Step 8: Jenkins status:"
sudo systemctl status jenkins

# Step 9: Get admin password
echo ""
echo "=========================================="
echo "JENKINS READY!"
echo "=========================================="
echo ""
echo "Jenkins Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || echo "NOT READY YET"
echo ""
echo "=========================================="
echo "Access Jenkins at:"
echo "http://3.26. 175.20:8080"
echo "=========================================="
