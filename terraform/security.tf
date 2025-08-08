# =============================================================================
# SECURITY GROUPS
# =============================================================================

# Security Group for Application Load Balancer
# This is the only security group that allows inbound traffic from the internet
# Acts as the first line of defense for the application
# Only allows HTTP (80) and HTTPS (443) traffic from anywhere
# Egress is limited to the frontend security group on port 3000
resource "aws_security_group" "alb" {
  name        = "image-editor-alb-sg"
  description = "Security group for Application Load Balancer - allows HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  # Inbound HTTP traffic from anywhere
  # Users will access the application through this port
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTPS traffic from anywhere
  # For secure connections (requires SSL certificate configuration)
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule will be added after frontend SG is created (see below)
  # This ensures ALB can only communicate with frontend, not directly to internet

  tags = {
    Name = "image-editor-alb-sg"
    Type = "ALB"
  }
}

# Security Group for Frontend  EC2 Instance
# Only accepts traffic from the ALB, not directly from internet
# This implements the security requirement that frontend is not directly accessible
# Can communicate with backend for API calls
resource "aws_security_group" "frontend" {
  name        = "image-editor-frontend-sg"
  description = "Security group for Frontend EC2 - only allows traffic from ALB"
  vpc_id      = aws_vpc.main.id

  # TODO:
  # If you want encryption between ALB → frontend (end-to-end TLS):
  # Make the instance serve HTTPS :443 only instead and use
  # an HTTPS target group → ingress 443 from the ALB security group
  #
  # Inbound traffic on port 3000 (Next.js default port) only from ALB
  # This ensures frontend can only be accessed through the load balancer
  ingress {
    description     = "Next.js port from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound HTTPS for package downloads, updates from internet
  # Required for npm install, system updates, etc.
  egress {
    description = "HTTPS to Internet for updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP for package repositories that might use HTTP
  egress {
    description = "HTTP to Internet for updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule to backend will be added after backend SG is created (see below)

  tags = {
    Name = "image-editor-frontend-sg"
    Type = "Frontend"
  }
}

# Security Group for Backend (FastAPI) EC2 Instance
# Most restricted security group - only accepts traffic from frontend
# Cannot initiate connections to the internet (only respond)
# This implements the security requirement that backend is isolated
resource "aws_security_group" "backend" {
  name        = "image-editor-backend-sg"
  description = "Security group for Backend EC2 - only allows traffic from Frontend"
  vpc_id      = aws_vpc.main.id


  # Inbound traffic on port 8080 (FastAPI port) only from Frontend
  # This ensures backend API can only be called by the frontend server
  ingress {
    description     = "FastAPI port from Frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Outbound HTTPS for Python package downloads (pip install)
  # Required for installing dependencies and updates
  egress {
    description = "HTTPS to Internet for pip packages"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP for package repositories
  egress {
    description = "HTTP to Internet for packages"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "image-editor-backend-sg"
    Type = "Backend"
  }
}

# =============================================================================
# SECURITY GROUP RULES - INTER-SERVICE COMMUNICATION
# =============================================================================

# ALB -> Frontend communication
# This rule allows the ALB to forward traffic to the frontend
# Added as a separate rule to avoid circular dependency
resource "aws_security_group_rule" "alb_to_frontend" {
  type                     = "egress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.frontend.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow ALB to communicate with Frontend"
}

# Frontend -> Backend communication
# This rule allows the frontend to make API calls to the backend
# Added as a separate rule to avoid circular dependency
resource "aws_security_group_rule" "frontend_to_backend" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.backend.id
  security_group_id        = aws_security_group.frontend.id
  description              = "Allow Frontend to communicate with Backend API"
}

# =============================================================================
# OPTIONAL: SSH ACCESS (for debugging - remove in production)
# =============================================================================

# Security Group for SSH Bastion/Jump Host (Optional)
# Uncomment if you need SSH access for debugging
# In production, use AWS Systems Manager Session Manager instead
/*
resource "aws_security_group" "ssh_bastion" {
  name        = "image-editor-ssh-bastion-sg"
  description = "Security group for SSH Bastion - debugging only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP_HERE/32"]  # Replace with your IP
  }

  egress {
    description = "SSH to private instances"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "image-editor-ssh-bastion-sg"
    Type = "Bastion"
  }
}
*/
