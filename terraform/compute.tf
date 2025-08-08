# =============================================================================
# IAM ROLES AND INSTANCE PROFILES
# =============================================================================

# IAM Role for EC2 Instances
# Allows EC2 instances to use AWS Systems Manager for remote access
resource "aws_iam_role" "ec2_role" {
  name = "image-editor-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Systems Manager policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile to attach IAM role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "image-editor-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

# Frontend EC2 Instance
# Runs Next.js application in private subnet
resource "aws_instance" "frontend" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.private.id
  
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  user_data = base64encode(templatefile("${path.module}/user-data/frontend.sh", {
    backend_private_ip = aws_instance.backend.private_ip
  }))
  
  depends_on = [aws_instance.backend]

  tags = {
    Name = "image-editor-frontend"
  }
}

# Backend EC2 Instance  
# Runs FastAPI application in private subnet
resource "aws_instance" "backend" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"
  subnet_id     = aws_subnet.private.id
  
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  user_data = base64encode(file("${path.module}/user-data/backend.sh"))

  tags = {
    Name = "image-editor-backend"
  }
}

# =============================================================================
# TARGET GROUP ATTACHMENT
# =============================================================================

# Register Frontend Instance with ALB
resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = 3000
}