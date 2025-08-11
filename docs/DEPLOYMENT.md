# Deployment Guide

## Prerequisites

Before the GitHub Actions workflows can deploy to EC2 instances, you need to:

1. **Deploy the Terraform Infrastructure**
   ```bash
   cd ../terraform-demo/terraform
   terraform init
   terraform plan
   terraform apply
   ```
   This will create:
   - EC2 instances tagged as `image-editor-backend` and `image-editor-frontend`
   - ECR repositories for Docker images
   - VPC, subnets, and security groups
   - IAM roles with SSM and ECR permissions
   - Application Load Balancer

2. **Set GitHub Secrets**
   In your GitHub repository settings, add these secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   
   These credentials need permissions for:
   - ECR (push images)
   - EC2 (describe instances)
   - SSM (send commands to instances)

## Deployment Workflows

### Automatic Deployment
The main workflow (`deploy-to-ecr.yml`) automatically:
1. Builds Docker images on push to main
2. Pushes images to ECR
3. Deploys to EC2 instances using SSM

### Manual Deployment
Use the `deploy-to-ec2.yml` workflow to:
- Manually trigger deployments from GitHub Actions UI
- Deploy specific components (backend/frontend/both)
- Useful for controlled production releases

### Rolling Deployment
Use the `rolling-deployment.yml` workflow for:
- Zero-downtime deployments
- Updates instances one at a time
- Includes health checks between updates

## Troubleshooting

### "No running backend/frontend instances found"
This means the EC2 instances haven't been created yet or are not running.

**Solution:**
1. Check if Terraform has been applied:
   ```bash
   cd ../terraform-demo/terraform
   terraform show
   ```

2. Verify instances are running:
   ```bash
   aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=image-editor-backend" \
               "Name=instance-state-name,Values=running" \
     --query "Reservations[].Instances[].InstanceId"
   ```

3. If instances exist but are stopped, start them:
   ```bash
   aws ec2 start-instances --instance-ids <instance-id>
   ```

### SSM Command Failed
If SSM commands fail, check:
1. Instance has SSM agent installed and running
2. Instance has proper IAM role attached
3. VPC endpoints are configured for SSM (in private subnets)

### Docker Pull Failed
If Docker can't pull from ECR:
1. Check ECR repositories exist
2. Verify instance IAM role has ECR permissions
3. Check VPC endpoints for ECR are configured

## Architecture Overview

```
GitHub Actions
    ↓
Build & Push to ECR
    ↓
SSM Send Command
    ↓
EC2 Instances (Private Subnet)
    ↓
Pull from ECR & Restart Services
    ↓
Application Load Balancer (Public)
    ↓
Users
```

## Instance Tags

The workflows identify EC2 instances by their Name tags:
- Backend: `Name=image-editor-backend`
- Frontend: `Name=image-editor-frontend`

These tags are set by Terraform during instance creation.