#!/bin/bash

# Jenkins Docker Setup Script
# Install Docker and run Jenkins in a container

set -e

echo "[*] ============================================"
echo "[*] Jenkins Docker Installation"
echo "[*] ============================================"
echo ""

# Update system
echo "[*] Updating system packages..."
sudo yum update -y

# Install Docker
echo "[*] Installing Docker..."
sudo yum install -y docker

# Start Docker service
echo "[*] Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
echo "[*] Adding ec2-user to docker group..."
sudo usermod -a -G docker ec2-user

echo "[OK] Docker installed successfully!"
echo ""

# Create jenkins directory for data persistence
echo "[*] Creating Jenkins data directory..."
mkdir -p ~/jenkins_home
sudo chown 1000:1000 ~/jenkins_home

# Pull Jenkins Docker image
echo "[*] Pulling Jenkins Docker image..."
sudo docker pull jenkins/jenkins:lts

echo "[OK] Jenkins image pulled!"
echo ""

# Run Jenkins container
echo "[*] Starting Jenkins container..."
sudo docker run \
  -d \
  --name jenkins \
  --restart always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

echo "[OK] Jenkins container started!"
echo ""

# Wait for Jenkins to initialize
echo "[*] Waiting 30 seconds for Jenkins to initialize..."
sleep 30

# Get initial admin password
echo "[*] Retrieving initial admin password..."
JENKINS_PASSWORD=$(sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

# Get instance IP
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "[OK] ============================================"
echo "[OK] Jenkins is ready!"
echo "[OK] ============================================"
echo ""
echo "Access Jenkins:"
echo "  URL: http://$INSTANCE_IP:8080"
echo ""
echo "Initial Admin Password:"
echo "  $JENKINS_PASSWORD"
echo ""
echo "Next Steps:"
echo "  1. Open http://$INSTANCE_IP:8080 in your browser"
echo "  2. Paste the password above"
echo "  3. Choose 'Install suggested plugins'"
echo "  4. Create your first admin user"
echo ""
echo "Useful Docker Commands:"
echo "  View logs:    sudo docker logs -f jenkins"
echo "  Stop:         sudo docker stop jenkins"
echo "  Start:        sudo docker start jenkins"
echo "  SSH:          ssh -i key.pem ec2-user@$INSTANCE_IP"
echo ""
