# Image Editor - Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the Image Editor application to Amazon EKS.

## Architecture

The application is deployed on Amazon EKS with the following components:

- **Backend**: FastAPI application running on port 8080
- **Frontend**: Next.js application running on port 3000
- **Ingress**: AWS Application Load Balancer (ALB) managed by AWS Load Balancer Controller
- **Namespace**: `image-editor` namespace for isolation

## Prerequisites

1. **EKS Cluster**: The EKS cluster must be created using the Terraform configuration in the `terraform-demo` repository
2. **AWS Load Balancer Controller**: Must be installed in the cluster
3. **ECR Repositories**: Backend and frontend images must be pushed to ECR
4. **kubectl**: Configured to access the EKS cluster
5. **AWS CLI**: Configured with appropriate credentials

## Directory Structure

```
k8s/
├── namespace.yaml                          # Namespace definition
├── backend-deployment.yaml                 # Backend deployment and service
├── frontend-deployment.yaml                # Frontend deployment and service
├── ingress.yaml                           # Ingress configuration for ALB
├── aws-load-balancer-controller-values.yaml # Helm values for AWS LB Controller
└── README.md                              # This file
```

## Deployment

### Automated Deployment (GitHub Actions)

The application is automatically deployed to EKS when:
- Code is pushed to the `main` branch
- The workflow is manually triggered from GitHub Actions

### Manual Deployment

1. **Update kubeconfig**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name image-editor-cluster
   ```

2. **Create namespace**:
   ```bash
   kubectl apply -f namespace.yaml
   ```

3. **Deploy backend**:
   ```bash
   kubectl apply -f backend-deployment.yaml
   ```

4. **Deploy frontend**:
   ```bash
   kubectl apply -f frontend-deployment.yaml
   ```

5. **Deploy ingress**:
   ```bash
   kubectl apply -f ingress.yaml
   ```

6. **Get the application URL**:
   ```bash
   kubectl get ingress image-editor-ingress -n image-editor
   ```

### Using the deployment script

```bash
cd ../scripts
./deploy-to-eks.sh
```

## Configuration

### Backend Configuration

- **Replicas**: 2 (for high availability)
- **Resources**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU
- **Health Checks**: Liveness and readiness probes on `/health`
- **Service Type**: ClusterIP (internal only)

### Frontend Configuration

- **Replicas**: 2 (for high availability)
- **Resources**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU
- **Health Checks**: Liveness and readiness probes on `/`
- **Service Type**: ClusterIP (internal only)
- **Environment Variables**:
  - `NEXT_PUBLIC_API_URL`: Points to backend service
  - `API_URL`: Points to backend service

### Ingress Configuration

- **Controller**: AWS Load Balancer Controller
- **Type**: Application Load Balancer (ALB)
- **Scheme**: Internet-facing
- **Target Type**: IP mode
- **Path Routing**:
  - `/api/*` → Backend service
  - `/*` → Frontend service

## Monitoring

### Check deployment status:
```bash
kubectl get deployments -n image-editor
```

### Check pod status:
```bash
kubectl get pods -n image-editor
```

### Check service status:
```bash
kubectl get services -n image-editor
```

### Check ingress status:
```bash
kubectl get ingress -n image-editor
```

### View pod logs:
```bash
# Backend logs
kubectl logs -l app=backend -n image-editor

# Frontend logs
kubectl logs -l app=frontend -n image-editor
```

## Scaling

### Manual scaling:
```bash
# Scale backend
kubectl scale deployment backend --replicas=3 -n image-editor

# Scale frontend
kubectl scale deployment frontend --replicas=3 -n image-editor
```

### Auto-scaling (HPA):
To enable auto-scaling, create a Horizontal Pod Autoscaler:
```bash
kubectl autoscale deployment backend --cpu-percent=70 --min=2 --max=10 -n image-editor
kubectl autoscale deployment frontend --cpu-percent=70 --min=2 --max=10 -n image-editor
```

## Updating Images

### Update backend image:
```bash
kubectl set image deployment/backend backend=642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-backend:new-tag -n image-editor
```

### Update frontend image:
```bash
kubectl set image deployment/frontend frontend=642375200181.dkr.ecr.us-east-1.amazonaws.com/image-editor-frontend:new-tag -n image-editor
```

### Check rollout status:
```bash
kubectl rollout status deployment/backend -n image-editor
kubectl rollout status deployment/frontend -n image-editor
```

## Troubleshooting

### Pod not starting:
```bash
kubectl describe pod <pod-name> -n image-editor
kubectl logs <pod-name> -n image-editor
```

### Ingress not getting ALB address:
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress events
kubectl describe ingress image-editor-ingress -n image-editor
```

### Service not accessible:
```bash
# Test service internally
kubectl run test-pod --image=busybox -it --rm --restart=Never -- wget -qO- http://backend.image-editor.svc.cluster.local:8080/health
```

## Clean Up

To remove all resources:
```bash
kubectl delete namespace image-editor
```

This will delete all resources in the namespace including deployments, services, and ingress.