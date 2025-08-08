terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Fetch all available AWS availability zones in the current region
# This ensures we're using active AZs and makes the infrastructure portable
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the most recent Amazon Linux 2023 AMI
# AL2023 is the latest generation Amazon Linux with improved performance and security
# It comes with systemd, DNF package manager, and better container support
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# NETWORKING - VPC
# =============================================================================

# Virtual Private Cloud (VPC)
# This creates an isolated network environment for our application
# Using 10.0.0.0/16 gives us 65,536 IP addresses to work with
# DNS support is enabled for internal service discovery
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "image-editor-vpc"
  }
}

# Internet Gateway
# This provides internet connectivity for resources in public subnets
# Required for the ALB to receive traffic from the internet
# Also enables outbound internet access for resources in public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "image-editor-igw"
  }
}

# =============================================================================
# NETWORKING - SUBNETS
# =============================================================================

# Public Subnets (2 required for ALB high availability)
# These subnets will host the Application Load Balancer
# They have direct routes to the Internet Gateway for public access
# Using /24 subnet mask gives 256 IPs per subnet (AWS reserves 5 per subnet)
# Spread across 2 AZs for high availability as required by ALB
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true # Auto-assign public IPs to instances launched here

  tags = {
    Name = "image-editor-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnet for Frontend and Backend EC2 instances
# This subnet has no direct internet route - only through NAT Gateway
# This provides security by preventing direct inbound connections from internet
# Both frontend and backend servers will be placed here for protection
# Using offset of 10 to clearly separate from public subnet ranges
# Single subnet simplifies architecture and reduces cross-AZ data transfer costs
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, 10) # 10.0.10.0/24
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "image-editor-private-subnet"
    Type = "Private"
  }
}

# =============================================================================
# NETWORKING - NAT GATEWAY
# =============================================================================

# Elastic IP for NAT Gateway
# This provides a static public IP address for the NAT Gateway
# Ensures consistent outbound IP for services that might whitelist our traffic
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "image-editor-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
# Enables outbound internet connectivity for resources in private subnets
# Required for EC2 instances to download packages, Docker images, etc.
# Placed in public subnet so it can reach the Internet Gateway
#
# NOTE: Cost-saving but a single-AZ SPOF and can incur cross-AZ data charges
# if we eventually add another private subnet in another AZ. Best practice
# for prod: one NAT per AZ and route each private subnet to its local NAT.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "image-editor-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NETWORKING - ROUTE TABLES
# =============================================================================

# Route Table for Public Subnets
# Directs all non-local traffic (0.0.0.0/0) to the Internet Gateway
# This enables both inbound and outbound internet connectivity
# Local traffic within VPC (10.0.0.0/16) is automatically routed
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "image-editor-public-rt"
  }
}

# Route Table for Private Subnets
# Directs all non-local traffic (0.0.0.0/0) to the NAT Gateway
# This enables outbound-only internet connectivity (no inbound initiation)
# Essential for instances to download updates while remaining protected
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "image-editor-private-rt"
  }
}

# Route Table Associations for Public Subnets
# Links each public subnet to the public route table
# Without this, subnets would only have access to the default VPC route table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Private Subnet
# Links the private subnet to the private route table
# Ensures private subnet traffic goes through NAT for internet access
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
