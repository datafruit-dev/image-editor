#!/bin/bash

# Deploy script for updating EC2 instances with latest Docker images from ECR
# This script can be run manually or integrated into CI/CD pipelines

set -e

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REGISTRY="${ECR_REGISTRY}"
BACKEND_REPO="image-editor-backend"
FRONTEND_REPO="image-editor-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Get ECR registry if not provided
if [ -z "$ECR_REGISTRY" ]; then
    print_status "Getting ECR registry URL..."
    ECR_REGISTRY=$(aws ecr describe-repositories --repository-names $BACKEND_REPO --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text | sed 's/\/image-editor-backend$//')
    if [ -z "$ECR_REGISTRY" ]; then
        print_error "Could not determine ECR registry URL"
        exit 1
    fi
fi

print_status "ECR Registry: $ECR_REGISTRY"

# Function to update an EC2 instance
update_instance() {
    local INSTANCE_NAME=$1
    local CONTAINER_NAME=$2
    local ECR_REPO=$3
    local PORT=$4
    local EXTRA_ENV=$5
    
    print_status "Updating $INSTANCE_NAME..."
    
    # Get instance ID
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text \
        --region $AWS_REGION)
    
    if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
        print_warning "$INSTANCE_NAME not found or not running. Skipping..."
        return
    fi
    
    print_status "Found instance: $INSTANCE_ID"
    
    # Prepare docker run command
    DOCKER_RUN_CMD="docker run -d --name $CONTAINER_NAME --restart always -p $PORT:$PORT"
    if [ ! -z "$EXTRA_ENV" ]; then
        DOCKER_RUN_CMD="$DOCKER_RUN_CMD $EXTRA_ENV"
    fi
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD $ECR_REGISTRY/$ECR_REPO:latest"
    
    # Send update commands via SSM
    print_status "Sending update commands to $INSTANCE_NAME..."
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[
            'echo \"Updating $CONTAINER_NAME container...\"',
            'aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY',
            'docker pull $ECR_REGISTRY/$ECR_REPO:latest',
            'docker stop $CONTAINER_NAME 2>/dev/null || true',
            'docker rm $CONTAINER_NAME 2>/dev/null || true',
            '$DOCKER_RUN_CMD',
            'docker ps | grep $CONTAINER_NAME'
        ]" \
        --output text \
        --query 'Command.CommandId' \
        --region $AWS_REGION)
    
    if [ ! -z "$COMMAND_ID" ]; then
        print_status "Command sent with ID: $COMMAND_ID"
        
        # Wait for command to complete
        print_status "Waiting for deployment to complete..."
        sleep 10
        
        # Check command status
        STATUS=$(aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID" \
            --query 'Status' \
            --output text \
            --region $AWS_REGION 2>/dev/null || echo "Pending")
        
        print_status "Deployment status: $STATUS"
    else
        print_error "Failed to send command to $INSTANCE_NAME"
    fi
}

# Main deployment process
print_status "Starting deployment to EC2 instances..."

# Update Backend
update_instance "image-editor-backend" "backend" "$BACKEND_REPO" "8080" ""

# Get backend private IP for frontend environment variable
BACKEND_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=image-editor-backend" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PrivateIpAddress" \
    --output text \
    --region $AWS_REGION)

if [ ! -z "$BACKEND_IP" ] && [ "$BACKEND_IP" != "None" ]; then
    # Update Frontend with backend URL
    update_instance "image-editor-frontend" "frontend" "$FRONTEND_REPO" "3000" "-e BACKEND_URL=http://$BACKEND_IP:8080"
else
    print_warning "Could not get backend IP. Frontend may not connect properly to backend."
    update_instance "image-editor-frontend" "frontend" "$FRONTEND_REPO" "3000" ""
fi

print_status "Deployment process completed!"

# Get ALB URL for accessing the application
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "image-editor-alb" \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region $AWS_REGION 2>/dev/null)

if [ ! -z "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
    print_status "Application should be accessible at: http://$ALB_DNS"
fi