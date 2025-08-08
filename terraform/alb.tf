# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

# Application Load Balancer
# This is the entry point for all external traffic to the application
# Deployed across multiple public subnets for high availability
# Handles SSL termination (if configured) and routes traffic to frontend instances
# Health checks ensure traffic only goes to healthy instances
resource "aws_lb" "main" {
  name               = "image-editor-alb"
  internal           = false  # Internet-facing, not internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # Deploy across all public subnets

  # Prevent accidental deletion in production
  enable_deletion_protection = false  # Set to true in production

  # Enable access logs for debugging and compliance (optional)
  # Requires S3 bucket configuration
  /*
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }
  */

  tags = {
    Name = "image-editor-alb"
    Type = "Application"
  }
}

# =============================================================================
# TARGET GROUPS
# =============================================================================

# Target Group for Frontend Instances
# Defines how the ALB routes traffic to frontend EC2 instances
# Health checks ensure only healthy instances receive traffic
# Sticky sessions can be enabled if needed for stateful applications
resource "aws_lb_target_group" "frontend" {
  name     = "image-editor-frontend-tg"
  port     = 3000  # Next.js default port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
  # ALB will regularly check this endpoint to determine instance health
  # Unhealthy instances are automatically removed from rotation
  health_check {
    enabled             = true
    healthy_threshold   = 2    # Number of consecutive successful checks before considering healthy
    unhealthy_threshold = 2    # Number of consecutive failed checks before considering unhealthy
    timeout             = 5    # Seconds to wait for a response
    interval            = 30   # Seconds between health checks
    path                = "/"  # Health check endpoint - Next.js root
    matcher             = "200" # Expected HTTP response code
  }

  # Deregistration delay - time to wait for in-flight requests to complete
  # Before removing an instance from the target group
  deregistration_delay = 30

  # Sticky sessions configuration (optional)
  # Ensures a user always hits the same instance - useful for stateful apps
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = false  # Enable if your app requires session affinity
  }

  tags = {
    Name = "image-editor-frontend-tg"
    Type = "Frontend"
  }
}

# =============================================================================
# LISTENERS
# =============================================================================

# HTTP Listener (Port 80)
# Handles incoming HTTP traffic and routes it to the frontend target group
# In production, this should redirect to HTTPS for security
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - forward to frontend
  # Can be modified to redirect to HTTPS in production
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  # Alternative: Redirect HTTP to HTTPS (uncomment for production)
  /*
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  */
}

# HTTPS Listener (Port 443) - Optional
# Uncomment this section when you have an SSL certificate
# You'll need to either:
# 1. Use AWS Certificate Manager (ACM) for free SSL certificates
# 2. Import your own certificate
/*
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # Use latest TLS policy
  certificate_arn   = aws_acm_certificate.main.arn  # Reference your certificate

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
*/

# =============================================================================
# LISTENER RULES (Optional - for path-based routing)
# =============================================================================

# Example: Route /api/* directly to a backend target group
# This would bypass the frontend for API calls if needed
/*
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn  # Would need to create this
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
*/