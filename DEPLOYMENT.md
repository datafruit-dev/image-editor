# Deployment Guide for Image Editor Application

## Overview

This document describes the deployment process for the Image Editor application to AWS infrastructure using ECR (Elastic Container Registry) and EC2 instances.

## Current Issues Fixed

The original GitHub Actions workflow (`deploy-to-ecr.yml`) had a critical issue:
- ❌ **Only pushed images to ECR** but didn't deploy them to EC2 instances
- ❌ **EC2 instances only pulled images once** during initial boot
- ❌ **No automatic updates** when new images were pushed

## Solution Implemented

### 1. Enhanced GitHub Actions Workflow

Created a new workflow file: `.github/workflows/deploy-to-ec2.yml`

This workflow:
- ✅ Builds and pushes Docker images to ECR
- ✅ Automatically updates running EC2 instances with new images
- ✅ Uses AWS Systems Manager (SSM) to send deployment commands
- ✅ Performs health checks after deployment

### 2. Manual Deployment Script

Created a deployment script: `scripts/deploy-to-ec2.sh`

This script can be used for:
- Manual deployments
- Troubleshooting
- Integration with other CI/CD tools

## Prerequisites

### GitHub Secrets Required

Configure these secrets in your GitHub repository:
- `AWS_ACCESS_KEY_ID`: AWS access key with necessary permissions
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key

### AWS Permissions Required

The AWS IAM user/role needs permissions for:
- ECR: Push and pull images
- EC2: Describe instances
- SSM: Send commands to EC2 instances
- ELB: Describe load balancers (optional, for getting ALB URL)

### Terraform Infrastructure

Ensure the Terraform infrastructure is deployed with:
- ECR repositories: `image-editor-backend` and `image-editor-frontend`
- EC2 instances with tags:
  - Backend: `Name=image-editor-backend`
  - Frontend: `Name=image-editor-frontend`
- IAM roles with SSM permissions attached to EC2 instances

## Deployment Process

### Automatic Deployment (GitHub Actions)

1. Push code to the `main` branch
2. GitHub Actions workflow automatically:
   - Builds Docker images
   - Pushes to ECR
   - Updates EC2 instances
   - Restarts containers with new images

### Manual Deployment

1. Ensure AWS CLI is configured:
   ```bash
   aws configure
   ```

2. Run the deployment script:
   ```bash
   ./scripts/deploy-to-ec2.sh
   ```

3. The script will:
   - Pull latest images from ECR to EC2 instances
   - Stop old containers
   - Start new containers with updated images
   - Display the application URL

## How It Works

### Image Building and Pushing
1. Docker images are built from `backend/Dockerfile` and `frontend/Dockerfile`
2. Images are tagged with both commit SHA and `latest`
3. Images are pushed to ECR repositories

### EC2 Instance Updates
1. The workflow/script identifies running EC2 instances by their tags
2. Uses AWS Systems Manager to send commands to instances
3. Commands executed on each instance:
   - Authenticate with ECR
   - Pull latest Docker image
   - Stop and remove old container
   - Start new container with updated image
   - Configure environment variables (e.g., BACKEND_URL for frontend)

### Container Management
- Containers are configured with `--restart always` flag
- Systemd services ensure containers start on boot
- Health checks verify deployment success

## Monitoring Deployment

### Check Deployment Status

1. **Via AWS Console:**
   - Go to Systems Manager > Run Command
   - View command execution status

2. **Via CLI:**
   ```bash
   aws ssm list-command-invocations --command-id <command-id>
   ```

3. **Check Container Status on EC2:**
   ```bash
   # Connect to instance via Session Manager
   aws ssm start-session --target <instance-id>
   
   # Check Docker containers
   docker ps
   docker logs backend  # or frontend
   ```

### Access the Application

After successful deployment:
1. Get the ALB URL from Terraform outputs or AWS Console
2. Access the application at: `http://<alb-dns-name>`

## Troubleshooting

### Common Issues

1. **SSM Commands Fail:**
   - Ensure EC2 instances have SSM agent installed and running
   - Verify IAM role has `AmazonSSMManagedInstanceCore` policy

2. **Docker Pull Fails:**
   - Check ECR repository permissions
   - Verify EC2 IAM role has ECR pull permissions

3. **Containers Don't Start:**
   - Check Docker logs: `docker logs <container-name>`
   - Verify port availability
   - Check environment variables

### Debug Commands

```bash
# Check if instances are running
aws ec2 describe-instances --filters "Name=tag:Name,Values=image-editor-*"

# Check ECR repositories
aws ecr describe-repositories --repository-names image-editor-backend image-editor-frontend

# Test SSM connectivity
aws ssm describe-instance-information --filters "Key=tag:Name,Values=image-editor-*"
```

## Security Considerations

1. **Secrets Management:**
   - Use GitHub Secrets for AWS credentials
   - Consider using AWS IAM roles for GitHub Actions (OIDC)

2. **Network Security:**
   - EC2 instances are in private subnets
   - Only ALB is publicly accessible
   - Security groups restrict traffic appropriately

3. **Image Security:**
   - ECR scanning is enabled for vulnerability detection
   - Use specific image tags in production (not just `latest`)

## Future Improvements

1. **Blue-Green Deployment:**
   - Implement zero-downtime deployments
   - Use multiple target groups with ALB

2. **Auto-Scaling:**
   - Add Auto Scaling Groups for EC2 instances
   - Implement health checks and automatic recovery

3. **Container Orchestration:**
   - Consider migrating to ECS or EKS for better container management
   - Implement service discovery and load balancing

4. **Monitoring:**
   - Add CloudWatch alarms for deployment failures
   - Implement application performance monitoring

5. **Rollback Capability:**
   - Tag images with version numbers
   - Implement automatic rollback on failure