#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting EKS deployment...${NC}"

# Variables
CLUSTER_NAME="image-editor-cluster"
REGION="us-east-1"
NAMESPACE="image-editor"
ECR_REGISTRY="642375200181.dkr.ecr.us-east-1.amazonaws.com"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists kubectl; then
    echo -e "${RED}kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

if ! command_exists aws; then
    echo -e "${RED}AWS CLI is not installed. Please install AWS CLI first.${NC}"
    exit 1
fi

if ! command_exists helm; then
    echo -e "${RED}Helm is not installed. Please install Helm first.${NC}"
    exit 1
fi

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig for cluster ${CLUSTER_NAME}...${NC}"
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}

# Verify cluster connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating namespace ${NAMESPACE}...${NC}"
kubectl apply -f k8s/namespace.yaml

# Install AWS Load Balancer Controller if not already installed
echo -e "${YELLOW}Checking AWS Load Balancer Controller...${NC}"
if ! helm list -n kube-system | grep -q aws-load-balancer-controller; then
    echo -e "${GREEN}Installing AWS Load Balancer Controller...${NC}"
    
    # Add the EKS Helm repo
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Get the VPC ID
    VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --query "cluster.resourcesVpcConfig.vpcId" --output text)
    
    # Get the IAM role ARN from Terraform output
    AWS_LB_CONTROLLER_ROLE_ARN=$(aws iam get-role --role-name aws-load-balancer-controller --query 'Role.Arn' --output text 2>/dev/null)
    
    if [ -z "$AWS_LB_CONTROLLER_ROLE_ARN" ]; then
        echo -e "${RED}AWS Load Balancer Controller IAM role not found. Please run Terraform first.${NC}"
        exit 1
    fi
    
    # Install the controller
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${AWS_LB_CONTROLLER_ROLE_ARN} \
        --set region=${REGION} \
        --set vpcId=${VPC_ID} \
        --wait
else
    echo -e "${GREEN}AWS Load Balancer Controller is already installed${NC}"
fi

# Deploy backend
echo -e "${YELLOW}Deploying backend...${NC}"
kubectl apply -f k8s/backend-deployment.yaml

# Deploy frontend
echo -e "${YELLOW}Deploying frontend...${NC}"
kubectl apply -f k8s/frontend-deployment.yaml

# Deploy ingress
echo -e "${YELLOW}Deploying ingress...${NC}"
kubectl apply -f k8s/ingress.yaml

# Wait for deployments to be ready
echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/backend -n ${NAMESPACE}
kubectl wait --for=condition=available --timeout=300s deployment/frontend -n ${NAMESPACE}

# Get the ALB URL
echo -e "${YELLOW}Waiting for ALB to be provisioned...${NC}"
sleep 30

ALB_URL=""
for i in {1..30}; do
    ALB_URL=$(kubectl get ingress image-editor-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$ALB_URL" ]; then
        break
    fi
    echo "Waiting for ALB... (attempt $i/30)"
    sleep 10
done

if [ -z "$ALB_URL" ]; then
    echo -e "${RED}Failed to get ALB URL after 5 minutes${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}Application URL: http://${ALB_URL}${NC}"
echo ""
echo "To check the status of your deployments:"
echo "  kubectl get deployments -n ${NAMESPACE}"
echo ""
echo "To check the pods:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "To check the services:"
echo "  kubectl get services -n ${NAMESPACE}"
echo ""
echo "To check the ingress:"
echo "  kubectl get ingress -n ${NAMESPACE}"