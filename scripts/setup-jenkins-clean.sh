#!/bin/bash
set -e

echo "========================================"
echo "JENKINS CLEAN UNINSTALL & SETUP"
echo "========================================"
echo ""

# STEP 1: Uninstall old packages
echo "STEP 1: Stopping and uninstalling old packages..."
sudo systemctl stop jenkins || true
sudo systemctl stop docker || true
sudo systemctl disable jenkins || true
sudo systemctl disable docker || true
sudo yum remove -y jenkins java-11-amazon-corretto java-21-amazon-corretto docker || true
sudo rm -rf /var/lib/jenkins
sudo rm -rf /etc/yum.repos.d/jenkins.repo
sudo rm -rf /etc/yum.repos.d/corretto.repo
sudo yum clean all
echo "✓ Old packages removed"
echo ""

# STEP 2: Update system
echo "STEP 2: Updating system packages..."
sudo yum update -y
echo "✓ System updated"
echo ""

# STEP 3: Install Java 21 (latest supported)
echo "STEP 3: Installing Java 21..."
sudo yum install -y java-21-amazon-corretto
sudo alternatives --install /usr/bin/java java /usr/lib/jvm/java-21-amazon-corretto/bin/java 1
java -version
echo "✓ Java 21 installed"
echo ""

# STEP 4: Install Jenkins (latest)
echo "STEP 4: Installing Jenkins (latest)..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins
echo "✓ Jenkins installed"
echo ""

# STEP 5: Install Docker
echo "STEP 5: Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker jenkins
sudo usermod -a -G docker ec2-user
echo "✓ Docker installed and configured"
echo ""

# STEP 6: Install kubectl
echo "STEP 6: Installing kubectl..."
curl -o /tmp/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/
kubectl version --client
echo "✓ kubectl installed"
echo ""

# STEP 7: Install AWS CLI v2
echo "STEP 7: Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install
aws --version
echo "✓ AWS CLI v2 installed"
echo ""

# STEP 8: Start Jenkins
echo "STEP 8: Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
sleep 10
sudo systemctl status jenkins
echo "✓ Jenkins started"
echo ""

# STEP 9: Get Jenkins admin password
echo "========================================"
echo "JENKINS SETUP COMPLETE!"
echo "========================================"
echo ""
echo "Jenkins Admin Password:"
echo ""
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "========================================"
echo "Access Jenkins at: http://3.26.175.20:8080"
echo "========================================"
