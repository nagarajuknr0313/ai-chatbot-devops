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

    stages {
        stage('🔍 Checkout') {
            steps {
                checkout scm
                script {
                    echo "✅ Checking out branch: ${env.GIT_BRANCH}"
                    echo "✅ Commit: ${env.GIT_COMMIT}"
                }
            }
        }

        stage('🐳 Build Backend Image') {
            steps {
                script {
                    echo "🔨 Building backend image: ${BACKEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${BACKEND_IMAGE}:${BUILD_TAG} \
                            -t ${BACKEND_IMAGE}:latest \
                            -f backend/Dockerfile \
                            backend/
                    '''
                }
            }
        }

        stage('🎨 Build Frontend Image') {
            steps {
                script {
                    echo "🔨 Building frontend image: ${FRONTEND_IMAGE}:${BUILD_TAG}"
                    sh '''
                        docker build \
                            -t ${FRONTEND_IMAGE}:${BUILD_TAG} \
                            -t ${FRONTEND_IMAGE}:latest \
                            -f frontend/Dockerfile \
                            frontend/
                    '''
                }
            }
        }

        stage('📦 Push to ECR') {
            steps {
                script {
                    echo "🚀 Pushing images to ECR..."
                    sh '''
                        # Login to ECR
                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${ECR_REGISTRY}

                        # Push backend
                        echo "Pushing backend: ${BACKEND_IMAGE}:${BUILD_TAG}"
                        docker push ${BACKEND_IMAGE}:${BUILD_TAG}
                        docker push ${BACKEND_IMAGE}:latest

                        # Push frontend
                        echo "Pushing frontend: ${FRONTEND_IMAGE}:${BUILD_TAG}"
                        docker push ${FRONTEND_IMAGE}:${BUILD_TAG}
                        docker push ${FRONTEND_IMAGE}:latest
                    '''
                }
            }
        }

        stage('☸️ Deploy to EKS') {
            steps {
                script {
                    echo "📋 Deploying to EKS cluster: ${EKS_CLUSTER_NAME}"
                    sh '''
                        # Configure kubectl
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER_NAME}

                        # Restart deployments to pull new images
                        echo "🔄 Restarting backend deployment..."
                        kubectl rollout restart deployment/backend -n ${K8S_NAMESPACE}
                        kubectl rollout status deployment/backend -n ${K8S_NAMESPACE} --timeout=5m

                        echo "🔄 Restarting frontend deployment..."
                        kubectl rollout restart deployment/frontend -n ${K8S_NAMESPACE}
                        kubectl rollout status deployment/frontend -n ${K8S_NAMESPACE} --timeout=5m

                        # Get deployment info
                        echo "📊 Deployment Status:"
                        kubectl get deployments -n ${K8S_NAMESPACE}
                        kubectl get pods -n ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        stage('✅ Verify Deployment') {
            steps {
                script {
                    echo "🔍 Verifying deployment health..."
                    sh '''
                        # Check if all pods are running
                        BACKEND_READY=$(kubectl get deployment backend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
                        FRONTEND_READY=$(kubectl get deployment frontend -n ${K8S_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

                        if [[ "$BACKEND_READY" == "True" && "$FRONTEND_READY" == "True" ]]; then
                            echo "✅ All deployments are healthy!"
                            exit 0
                        else
                            echo "❌ Deployment health check failed!"
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline executed successfully!'
            // Uncomment below to enable Slack notifications
            // sh 'curl -X POST -H "Content-type: application/json" --data "{\\"text\\":\\"✅ Deployment to EKS successful\\"}" $SLACK_WEBHOOK'
        }
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }
        always {
            // Cleanup
            sh 'docker logout ${ECR_REGISTRY} || true'
        }
    }
}
