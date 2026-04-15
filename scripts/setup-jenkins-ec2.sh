#!/bin/bash
# Jenkins Setup Script for EC2
# Run this on your EC2 instance to automatically setup Jenkins

set -e

echo "======================================"
echo "🚀 Installing Jenkins on EC2"
echo "======================================"

# 1. Update system
echo "📦 Updating system packages..."
sudo yum update -y

# 2. Install Java (Required for Jenkins)
echo "☕ Installing Java 11..."
sudo yum install -y java-11-amazon-corretto

# 3. Install Jenkins
echo "🤖 Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install -y jenkins

# 4. Install Docker
echo "🐳 Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker jenkins

# 5. Install kubectl
echo "☸️  Installing kubectl..."
curl -o /tmp/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.27.0/2023-04-11/bin/linux/amd64/kubectl
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/

# 6. Install AWS CLI v2
echo "🌐 Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install

# 7. Start Jenkins
echo "🔥 Starting Jenkins..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo ""
echo "======================================"
echo "✅ Jenkins Installation Complete!"
echo "======================================"
echo ""
echo "📋 Jenkins Access Details:"
echo "  URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "  Get initial admin password:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "⚠️  Security Notes:"
echo "  1. Update security group to restrict port 8080"
echo "  2. Configure SSL/HTTPS"
echo "  3. Create admin user in Jenkins UI"
echo "  4. Install recommended plugins"
echo ""
echo "Next Steps:"
echo "  1. Open Jenkins UI in browser"
echo "  2. Configure AWS credentials"
echo "  3. Create pipeline job"
echo "  4. Setup GitHub webhook"
echo "======================================"
