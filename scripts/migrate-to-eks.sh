#!/bin/bash

# Migration script from EC2 to EKS deployment
# This script helps transition from EC2-based deployment to EKS

set -e

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REGISTRY=${ECR_REGISTRY:-"642375200181.dkr.ecr.us-east-1.amazonaws.com"}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME:-"image-editor-cluster"}
NAMESPACE="image-editor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Image Editor Migration to EKS ===${NC}"
echo "Region: $AWS_REGION"
echo "ECR Registry: $ECR_REGISTRY"
echo "EKS Cluster: $EKS_CLUSTER_NAME"
echo ""

# Function to check command availability
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command aws
check_command kubectl
check_command docker

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"

# Check if EKS cluster exists
echo -e "${YELLOW}Checking EKS cluster...${NC}"
if ! aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
    echo -e "${RED}Error: EKS cluster '$EKS_CLUSTER_NAME' not found${NC}"
    echo "Please create the EKS cluster first using Terraform"
    exit 1
fi
echo -e "${GREEN}✓ EKS cluster found${NC}"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
echo -e "${GREEN}✓ Kubeconfig updated${NC}"

# Check cluster connectivity
echo -e "${YELLOW}Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to EKS cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to EKS cluster${NC}"

# Check if AWS Load Balancer Controller is installed
echo -e "${YELLOW}Checking AWS Load Balancer Controller...${NC}"
if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    echo -e "${YELLOW}Warning: AWS Load Balancer Controller not found${NC}"
    echo "The ALB Ingress will not work without it."
    echo "Install it using: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ AWS Load Balancer Controller found${NC}"
fi

# Check ECR repositories
echo -e "${YELLOW}Checking ECR repositories...${NC}"
for repo in image-editor-backend image-editor-frontend; do
    if ! aws ecr describe-repositories --repository-names $repo --region $AWS_REGION &> /dev/null; then
        echo -e "${RED}Error: ECR repository '$repo' not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ ECR repository '$repo' exists${NC}"
done

# Check for existing EC2 instances
echo -e "${YELLOW}Checking existing EC2 deployments...${NC}"
BACKEND_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=image-editor-backend-*" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

FRONTEND_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=image-editor-frontend-*" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ ! -z "$BACKEND_INSTANCES" ] || [ ! -z "$FRONTEND_INSTANCES" ]; then
    echo -e "${YELLOW}Found existing EC2 instances:${NC}"
    [ ! -z "$BACKEND_INSTANCES" ] && echo "  Backend: $BACKEND_INSTANCES"
    [ ! -z "$FRONTEND_INSTANCES" ] && echo "  Frontend: $FRONTEND_INSTANCES"
    echo -e "${YELLOW}These will continue running until manually terminated${NC}"
fi

# Deploy to EKS
echo ""
echo -e "${GREEN}=== Starting EKS Deployment ===${NC}"

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f k8s/namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"

# Deploy backend
echo -e "${YELLOW}Deploying backend...${NC}"
kubectl apply -f k8s/backend-deployment.yaml
echo -e "${GREEN}✓ Backend deployment created${NC}"

# Deploy frontend
echo -e "${YELLOW}Deploying frontend...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
echo -e "${GREEN}✓ Frontend deployment created${NC}"

# Deploy ingress
echo -e "${YELLOW}Deploying ingress...${NC}"
kubectl apply -f k8s/ingress.yaml
echo -e "${GREEN}✓ Ingress created${NC}"

# Deploy HPA
echo -e "${YELLOW}Deploying HPA...${NC}"
kubectl apply -f k8s/hpa.yaml
echo -e "${GREEN}✓ HPA created${NC}"

# Wait for deployments
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/image-editor-backend -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/image-editor-frontend -n $NAMESPACE --timeout=5m
echo -e "${GREEN}✓ Deployments ready${NC}"

# Get ingress URL
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${YELLOW}Waiting for ALB to be provisioned (this may take 2-3 minutes)...${NC}"

for i in {1..30}; do
    ALB_DNS=$(kubectl get ingress image-editor-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$ALB_DNS" ]; then
        echo -e "${GREEN}✓ Application is available at: http://$ALB_DNS${NC}"
        break
    fi
    echo -n "."
    sleep 10
done

if [ -z "$ALB_DNS" ]; then
    echo -e "${YELLOW}ALB is still provisioning. Check status with:${NC}"
    echo "kubectl get ingress -n $NAMESPACE"
fi

# Show status
echo ""
echo -e "${GREEN}=== Current Status ===${NC}"
kubectl get all -n $NAMESPACE

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Verify the application is working correctly on EKS"
echo "2. Update DNS records to point to the new ALB"
echo "3. Monitor the application for any issues"
echo "4. Once confirmed working, terminate EC2 instances:"
if [ ! -z "$BACKEND_INSTANCES" ]; then
    echo "   aws ec2 terminate-instances --instance-ids $BACKEND_INSTANCES"
fi
if [ ! -z "$FRONTEND_INSTANCES" ]; then
    echo "   aws ec2 terminate-instances --instance-ids $FRONTEND_INSTANCES"
fi
echo "5. Update GitHub Actions to use the new EKS workflow"
echo ""
echo -e "${GREEN}Migration script completed!${NC}"