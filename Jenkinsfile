pipeline {
    agent any
    
    environment {
        REGISTRY = 'docker.io'
        REGISTRY_CREDS = credentials('docker-credentials')
        BACKEND_IMAGE = "${REGISTRY}/chatbot/backend:${BUILD_NUMBER}"
        FRONTEND_IMAGE = "${REGISTRY}/chatbot/frontend:${BUILD_NUMBER}"
        GIT_REPO = 'https://github.com/yourusername/ai-chatbot-devops.git'
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
                            docker tag ${BACKEND_IMAGE} ${REGISTRY}/chatbot/backend:latest
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
                            docker tag ${FRONTEND_IMAGE} ${REGISTRY}/chatbot/frontend:latest
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
                    sh '''
                        kubectl set image deployment/chatbot-backend \
                            chatbot-backend=${BACKEND_IMAGE} -n chatbot || \
                        kubectl apply -f k8s/
                        
                        kubectl set image deployment/chatbot-frontend \
                            chatbot-frontend=${FRONTEND_IMAGE} -n chatbot || \
                        true
                        
                        kubectl rollout status deployment/chatbot-backend -n chatbot
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo 'Running health checks...'
                script {
                    sh '''
                        sleep 30
                        kubectl get pods -n chatbot
                        kubectl describe svc/chatbot-backend -n chatbot
                    '''
                }
            }
        }
    }
    
    post {
        always {
            node {
                label 'built-in'
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
