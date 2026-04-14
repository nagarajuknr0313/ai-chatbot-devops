FROM jenkins/jenkins:latest-jdk17

USER root

# Install Docker CLI, AWS CLI, kubectl, and Python
RUN apt-get update && \
    apt-get install -y \
    docker.io \
    docker-compose \
    python3 \
    python3-pip \
    curl \
    wget && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir awscli

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Create docker group and add jenkins user
RUN groupadd -f docker || true && \
    usermod -aG docker jenkins || true

# Configure sudo for jenkins user (optional)
RUN apt-get update && \
    apt-get install -y sudo && \
    echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    rm -rf /var/lib/apt/lists/*

USER jenkins

# Install Jenkins plugins for Docker and Kubernetes
RUN jenkins-plugin-cli --plugins \
    docker-plugin:latest \
    docker-workflow:latest \
    kubernetes:latest \
    pipeline-model-definition:latest \
    timestamper:latest \
    log-parser:latest

EXPOSE 8080 50000
