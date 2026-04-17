pipeline {
    agent any
    
    environment {
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '868987408656'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        BACKEND_IMAGE = "${ECR_REGISTRY}/chatbot-backend"
        FRONTEND_IMAGE = "${ECR_REGISTRY}/chatbot-frontend"
        K8S_NAMESPACE = 'chatbot'
        EKS_CLUSTER_NAME = 'ai-chatbot-cluster'
        BUILD_TAG = "${BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "[OK] Checked out branch: ${env.GIT_BRANCH}"
                    echo "[OK] Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('Verify Prerequisites') {
            steps {
                script {
                    echo "[*] Verifying Docker availability..."
                    sh '''
                        docker --version || (echo "[ERROR] Docker not found!" && exit 1)
                        docker ps > /dev/null && echo "[OK] Docker daemon is accessible"
                    '''
                    echo "[OK] Docker is available"
                    
                    echo "[*] Verifying AWS CLI..."
                    sh '''
                        aws --version || (echo "[ERROR] AWS CLI not found!" && exit 1)
                    '''
                    echo "[OK] AWS CLI is available"
                    
                    echo "[*] Verifying kubectl..."
                    sh '''
                        kubectl version --client || (echo "[ERROR] kubectl not found!" && exit 1)
                    '''
                    echo "[OK] kubectl is available"
                }
            }
        }

        stage('Build Backend Image') {
            steps {
                script {
                    echo "[*] Building backend image: ${BACKEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${BACKEND_IMAGE}:${BUILD_TAG} \
                            -t ${BACKEND_IMAGE}:latest \
                            -f backend/Dockerfile \
                            backend/
                    '''
                    echo "[OK] Backend image built successfully"
                }
            }
        }

        stage('Build Frontend Image') {
            steps {
                script {
                    echo "[*] Building frontend image: ${FRONTEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${FRONTEND_IMAGE}:${BUILD_TAG} \
                            -t ${FRONTEND_IMAGE}:latest \
                            -f frontend/Dockerfile \
                            frontend/
                    '''
                    echo "[OK] Frontend image built successfully"
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    script {
                        echo "[*] Authenticating with ECR..."
                        sh '''
                            set +e
                            
                            # Login to ECR
                            PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION})
                            if [ -z "$PASSWORD" ]; then
                                echo "[ERROR] Failed to get ECR login password. Check AWS credentials in Jenkins."
                                exit 1
                            fi
                            
                            echo "$PASSWORD" | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            if [ $? -ne 0 ]; then
                                echo "[ERROR] ECR login failed!"
                                exit 1
                            fi
                            
                            set -e
                            
                            echo "[*] Pushing backend image..."
                            docker push ${BACKEND_IMAGE}:${BUILD_TAG}
                            docker push ${BACKEND_IMAGE}:latest
                            echo "[OK] Backend image pushed"
                            
                            echo "[*] Pushing frontend image..."
                            docker push ${FRONTEND_IMAGE}:${BUILD_TAG}
                            docker push ${FRONTEND_IMAGE}:latest
                            echo "[OK] Frontend image pushed"
                            
                            echo "[OK] All images pushed to ECR successfully"
                        '''
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    script {
                        echo "[*] Configuring kubectl for EKS..."
                        sh '''
                            aws eks update-kubeconfig \
                                --region ${AWS_REGION} \
                                --name ${EKS_CLUSTER_NAME}
                            echo "[OK] kubectl configured"
                        '''
                        
                        echo "[*] Deploying to EKS cluster: ${EKS_CLUSTER_NAME}"
                        sh '''
                            echo "[*] Restarting backend deployment..."
                            kubectl rollout restart deployment/backend -n ${K8S_NAMESPACE}
                            kubectl rollout status deployment/backend -n ${K8S_NAMESPACE} --timeout=5m
                            echo "[OK] Backend deployment restarted"
                            
                            echo "[*] Restarting frontend deployment..."
                            kubectl rollout restart deployment/frontend -n ${K8S_NAMESPACE}
                            kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE} --timeout=5m
                            echo "[OK] Frontend deployment restarted"
                            
                            echo "[*] Deployment Status:"
                            kubectl get deployments -n ${K8S_NAMESPACE}
                            echo ""
                            kubectl get pods -n ${K8S_NAMESPACE}
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    script {
                        echo "[*] Verifying deployment health..."
                        sh '''#!/bin/bash
                            BACKEND_READY=$(kubectl get deployment backend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
                            FRONTEND_READY=$(kubectl get deployment frontend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

                            if [[ "$BACKEND_READY" == "True" && "$FRONTEND_READY" == "True" ]]; then
                                echo "[OK] All deployments are healthy!"
                                exit 0
                            else
                                echo "[ERROR] Deployment health check failed!"
                                echo "Backend status: $BACKEND_READY"
                                echo "Frontend status: $FRONTEND_READY"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo '[OK] Pipeline executed successfully! Code deployed to EKS.'
        }
        failure {
            echo '[ERROR] Pipeline failed! Check logs above for details.'
            echo '[INFO] Common issues:'
            echo '  - AWS Credentials not added to Jenkins (Manage Credentials)'
            echo '  - Docker socket not properly mounted in Jenkins container'
            echo '  - EKS cluster or namespace does not exist'
            echo '  - kubectl not configured on Jenkins'
        }
        always {
            sh 'docker logout ${ECR_REGISTRY} 2>/dev/null || true'
        }
    }
}
