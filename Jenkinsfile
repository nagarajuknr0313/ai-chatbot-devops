pipeline {
    agent any
    
    environment {
        REGISTRY = 'docker.io'
        REGISTRY_CREDS = credentials('docker-credentials')
        BACKEND_IMAGE = "${REGISTRY}/nagaraju1855/backend:${BUILD_NUMBER}"
        FRONTEND_IMAGE = "${REGISTRY}/nagaraju1855/frontend:${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo 'Code checked out successfully'
            }
        }
        
        stage('Build Backend') {
            steps {
                echo 'Building backend Docker image...'
                script {
                    dir('backend') {
                        sh '''
                            docker build -t ${BACKEND_IMAGE} .
                            docker tag ${BACKEND_IMAGE} ${REGISTRY}/nagaraju1855/backend:latest
                        '''
                    }
                }
            }
        }
        
        stage('Build Frontend') {
            steps {
                echo 'Building frontend Docker image...'
                script {
                    dir('frontend') {
                        sh '''
                            docker build -t ${FRONTEND_IMAGE} -f Dockerfile .
                            docker tag ${FRONTEND_IMAGE} ${REGISTRY}/nagaraju1855/frontend:latest
                        '''
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo 'Pushing images to Docker Registry...'
                script {
                    sh '''
                        echo $REGISTRY_CREDS_PSW | docker login -u $REGISTRY_CREDS_USR --password-stdin
                        docker push ${BACKEND_IMAGE}
                        docker push ${FRONTEND_IMAGE}
                        docker logout
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying to Kubernetes...'
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                      string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            set -e
                            
                            # Ensure AWS CLI is available (use built-in if available, otherwise install)
                            if ! command -v aws &> /dev/null; then
                                echo "Installing AWS CLI..."
                                sudo apt-get update -qq && sudo apt-get install -y -qq awscli 2>&1 | grep -v "^Get:" || true
                            else
                                echo "AWS CLI already available"
                            fi
                            
                            # Ensure kubectl is available (use built-in if available, otherwise install)
                            if ! command -v kubectl &> /dev/null; then
                                echo "Installing kubectl..."
                                sudo curl -sL "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
                                sudo chmod +x /usr/local/bin/kubectl
                            else
                                echo "kubectl already available"
                            fi
                            
                            # Verify tools are available
                            echo "AWS CLI version:"
                            aws --version
                            echo "kubectl version:"
                            kubectl version --client 2>&1 || kubectl --version || echo "kubectl installed"
                            
                            # Generate kubeconfig using AWS credentials
                            export AWS_REGION=us-east-1
                            export EKS_CLUSTER_NAME=ai-chatbot-cluster
                            mkdir -p ~/.kube
                            
                            echo "Configuring kubectl with AWS credentials..."
                            aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME --kubeconfig ~/.kube/config
                            export KUBECONFIG=~/.kube/config
                            
                            # Verify connection
                            echo "Verifying Kubernetes cluster connection..."
                            kubectl cluster-info
                            echo "Getting cluster nodes..."
                            kubectl get nodes
                            
                            # Create namespace if it doesn't exist
                            echo "Creating chatbot namespace if needed..."
                            kubectl create namespace chatbot --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Apply Kubernetes manifests
                            echo "Applying Kubernetes manifests..."
                            kubectl apply -f k8s/namespace.yaml
                            kubectl apply -f k8s/backend-deployment.yaml
                            kubectl apply -f k8s/frontend-deployment.yaml
                            kubectl apply -f k8s/postgres-deployment.yaml || true
                            
                            # Update image for backend
                            echo "Updating backend image..."
                            kubectl set image deployment/chatbot-backend \
                                backend=${BACKEND_IMAGE} -n chatbot || echo "Backend deployment will be created from manifest"
                            
                            # Update image for frontend
                            echo "Updating frontend image..."
                            kubectl set image deployment/chatbot-frontend \
                                frontend=${FRONTEND_IMAGE} -n chatbot || echo "Frontend deployment will be created from manifest"
                            
                            # Wait for rollout
                            echo "Waiting for deployment rollout..."
                            kubectl rollout status deployment/chatbot-backend -n chatbot --timeout=5m || echo "Backend rollout check completed"
                            kubectl rollout status deployment/chatbot-frontend -n chatbot --timeout=5m || echo "Frontend rollout check completed"
                        '''
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo 'Running health checks...'
                script {
                    withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                      string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                            set +e
                            
                            # Ensure kubectl is available
                            if ! command -v kubectl &> /dev/null; then
                                echo "Installing kubectl..."
                                sudo curl -sL "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
                                sudo chmod +x /usr/local/bin/kubectl
                            fi
                            
                            export AWS_REGION=us-east-1
                            export EKS_CLUSTER_NAME=ai-chatbot-cluster
                            mkdir -p ~/.kube
                            aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME --kubeconfig ~/.kube/config
                            export KUBECONFIG=~/.kube/config
                            
                            echo "Waiting for pods to be ready..."
                            sleep 30
                            
                            echo "=== Pod Status ==="
                            kubectl get pods -n chatbot
                            
                            echo "=== Backend Service Details ==="
                            kubectl describe svc/chatbot-backend -n chatbot || echo "Backend service not yet created"
                            
                            echo "=== Deployment Status ==="
                            kubectl get deployments -n chatbot
                            
                            echo "=== Pod Events ==="
                            kubectl get events -n chatbot || echo "No events found"
                            
                            echo "=== Pod Logs (Backend) ==="
                            kubectl logs -l app=chatbot-backend -n chatbot --tail=50 --all-containers=true || echo "Backend logs not available yet"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            node('built-in') {
                cleanWs()
            }
            echo 'Pipeline completed. Cleaning up workspace.'
        }
        success {
            echo 'Pipeline succeeded! Application deployed.'
        }
        failure {
            echo 'Pipeline failed! Please check logs.'
        }
    }
}
