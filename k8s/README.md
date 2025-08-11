# Image Editor - Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the Image Editor application to Amazon EKS.

## Prerequisites

1. **EKS Cluster**: An Amazon EKS cluster must be created and configured
2. **AWS Load Balancer Controller**: Required for ALB Ingress
3. **ECR Repositories**: Backend and frontend images must be pushed to ECR
4. **kubectl**: Configured to access your EKS cluster
5. **IAM Roles**: Proper IAM roles for pods to access AWS services

## Directory Structure

```
k8s/
├── namespace.yaml           # Kubernetes namespace definition
├── backend-deployment.yaml  # Backend deployment and service
├── frontend-deployment.yaml # Frontend deployment and service
├── ingress.yaml            # ALB Ingress configuration
├── hpa.yaml                # Horizontal Pod Autoscaler configurations
└── kustomization.yaml      # Kustomize configuration
```

## Deployment

### Using GitHub Actions (Recommended)

The deployment is automated via GitHub Actions workflow:

1. **Automatic deployment on push to main**:
   ```bash
   git push origin main
   ```

2. **Manual deployment**:
   - Go to Actions tab in GitHub
   - Select "Deploy to EKS" workflow
   - Click "Run workflow"
   - Select environment and components to deploy

### Manual Deployment

1. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name image-editor-cluster
   ```

2. **Deploy all resources**:
   ```bash
   kubectl apply -k k8s/
   ```

3. **Deploy specific components**:
   ```bash
   # Deploy namespace first
   kubectl apply -f k8s/namespace.yaml
   
   # Deploy backend
   kubectl apply -f k8s/backend-deployment.yaml
   
   # Deploy frontend
   kubectl apply -f k8s/frontend-deployment.yaml
   
   # Deploy ingress
   kubectl apply -f k8s/ingress.yaml
   
   # Deploy HPA
   kubectl apply -f k8s/hpa.yaml
   ```

## Updating Image Tags

### Using Kustomize:
```bash
cd k8s/
kustomize edit set image 642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-backend:new-tag
kustomize edit set image 642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-frontend:new-tag
kubectl apply -k .
```

### Direct update:
```bash
kubectl set image deployment/image-editor-backend backend=642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-backend:new-tag -n image-editor
kubectl set image deployment/image-editor-frontend frontend=642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-frontend:new-tag -n image-editor
```

## Monitoring

### Check deployment status:
```bash
kubectl get deployments -n image-editor
kubectl get pods -n image-editor
kubectl get svc -n image-editor
kubectl get ingress -n image-editor
```

### View logs:
```bash
# Backend logs
kubectl logs -f deployment/image-editor-backend -n image-editor

# Frontend logs
kubectl logs -f deployment/image-editor-frontend -n image-editor
```

### Check HPA status:
```bash
kubectl get hpa -n image-editor
```

## Scaling

### Manual scaling:
```bash
# Scale backend
kubectl scale deployment/image-editor-backend --replicas=5 -n image-editor

# Scale frontend
kubectl scale deployment/image-editor-frontend --replicas=5 -n image-editor
```

### HPA automatically scales based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Min replicas: 2
- Max replicas: 10

## Rollback

### Rollback to previous version:
```bash
kubectl rollout undo deployment/image-editor-backend -n image-editor
kubectl rollout undo deployment/image-editor-frontend -n image-editor
```

### Check rollout history:
```bash
kubectl rollout history deployment/image-editor-backend -n image-editor
kubectl rollout history deployment/image-editor-frontend -n image-editor
```

## Troubleshooting

### Pod not starting:
```bash
kubectl describe pod <pod-name> -n image-editor
kubectl logs <pod-name> -n image-editor
```

### Ingress not working:
```bash
# Check ALB provisioning
kubectl describe ingress image-editor-ingress -n image-editor

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Image pull errors:
```bash
# Verify ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 642375200181.dkr.ecr.us-east-1.amazonaws.com

# Check node IAM role has ECR permissions
```

## Clean Up

To remove all resources:
```bash
kubectl delete -k k8s/
# or
kubectl delete namespace image-editor
```

## Required Terraform Changes

The Terraform configuration in the demo repo needs to be updated to:

1. **Create EKS Cluster** instead of EC2 instances
2. **Configure node groups** with appropriate instance types
3. **Set up VPC and subnets** for EKS
4. **Install AWS Load Balancer Controller** for ALB Ingress
5. **Configure IAM roles** for service accounts (IRSA)
6. **Set up cluster autoscaler** (optional)

See the Terraform migration guide for detailed instructions.