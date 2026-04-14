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
                            # Install kubectl if not present
                            if ! command -v kubectl &> /dev/null; then
                                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                                chmod +x kubectl
                                export PATH=$PWD:$PATH
                            fi
                            
                            # Install awscli if not present
                            if ! command -v aws &> /dev/null; then
                                pip install --quiet awscli
                            fi
                            
                            # Generate kubeconfig using AWS credentials
                            export AWS_REGION=us-east-1
                            export EKS_CLUSTER_NAME=ai-chatbot-cluster
                            mkdir -p ~/.kube
                            aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME --kubeconfig ~/.kube/config
                            export KUBECONFIG=~/.kube/config
                            
                            # Verify connection
                            echo "Verifying Kubernetes cluster connection..."
                            kubectl cluster-info
                            kubectl get nodes
                            
                            # Apply Kubernetes manifests
                            echo "Applying Kubernetes manifests..."
                            kubectl apply -f k8s/
                            
                            # Update image for backend
                            echo "Updating backend image..."
                            kubectl set image deployment/chatbot-backend \
                                backend=${BACKEND_IMAGE} -n chatbot || true
                            
                            # Update image for frontend
                            echo "Updating frontend image..."
                            kubectl set image deployment/chatbot-frontend \
                                frontend=${FRONTEND_IMAGE} -n chatbot || true
                            
                            # Wait for rollout
                            echo "Waiting for deployment rollout..."
                            kubectl rollout status deployment/chatbot-backend -n chatbot --timeout=5m || true
                            kubectl rollout status deployment/chatbot-frontend -n chatbot --timeout=5m || true
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
                            kubectl describe svc/chatbot-backend -n chatbot || true
                            
                            echo "=== Deployment Status ==="
                            kubectl get deployments -n chatbot
                            
                            echo "=== Pod Logs (Backend) ==="
                            kubectl logs -l app=chatbot-backend -n chatbot --tail=20 || true
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
