# Image Editor

A web application for editing images - just a demo :)

## 🚀 Deployment

This application is deployed on **Amazon EKS** (Elastic Kubernetes Service) for scalability and reliability.

### Architecture

- **Frontend**: Next.js application
- **Backend**: FastAPI application
- **Infrastructure**: Amazon EKS with Application Load Balancer
- **Container Registry**: Amazon ECR

### Components

```
image-editor/
├── frontend/          # Next.js frontend application
│   └── Dockerfile
├── backend/           # FastAPI backend application
│   └── Dockerfile
└── .github/
    └── workflows/
        ├── deploy-to-eks.yml     # EKS deployment workflow
        ├── deploy-to-ecr.yml     # ECR build and push
        └── rolling-deployment.yml # Rolling deployment strategy
```

## 🔧 Local Development

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

## 🚢 Deployment Pipeline

### Automatic Deployment

Push to `main` branch triggers:
1. Build Docker images
2. Push to Amazon ECR
3. Deploy to EKS cluster
4. Update Kubernetes deployments

### Manual Deployment

1. Go to GitHub Actions
2. Select "Deploy to EKS" workflow
3. Choose component to deploy (backend/frontend/both)
4. Run workflow

## 📊 Monitoring

```bash
# Get application URL
kubectl get ingress -n image-editor

# Check deployment status
kubectl get deployments -n image-editor

# View logs
kubectl logs -f deployment/backend -n image-editor
kubectl logs -f deployment/frontend -n image-editor
```

## 🏗️ Infrastructure

Infrastructure is managed in the [terraform-demo](https://github.com/datafruit-dev/terraform-demo) repository:
- EKS cluster configuration
- VPC and networking
- ECR repositories
- IAM roles and policies

## 🔐 Environment Variables

### Frontend
- `NEXT_PUBLIC_API_URL`: Backend API URL
- `API_URL`: Internal API URL for SSR

### Backend
- `PORT`: Application port (default: 8080)

## 📚 Technologies

- **Frontend**: Next.js, React, TypeScript
- **Backend**: FastAPI, Python
- **Container**: Docker, Amazon ECR
- **Orchestration**: Kubernetes, Amazon EKS
- **CI/CD**: GitHub Actions
- **Infrastructure**: Terraform

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test locally
4. Submit a pull request
5. GitHub Actions will automatically deploy after merge

## 📝 License

This project is for demonstration purposes.