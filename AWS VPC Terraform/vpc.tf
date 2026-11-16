# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Internet Gateway (for public subnets)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}


# PUBLIC SUBNETS  (ALB, NAT Gateway, Bastion)
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-${var.azs[count.index]}"
    Tier    = "public"
    Project = var.project_name
  }
}

# PRIVATE SUBNETS  (Application servers)
resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10) # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = var.azs[count.index]

  tags = {
    Name    = "${var.project_name}-private-${var.azs[count.index]}"
    Tier    = "private"
    Project = var.project_name
  }
}

# DATA SUBNETS  (Databases – NO internet)
resource "aws_subnet" "data" {
  count = length(var.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100) # 10.0.100.0/24, 10.0.101.0/24
  availability_zone = var.azs[count.index]

  tags = {
    Name    = "${var.project_name}-data-${var.azs[count.index]}"
    Tier    = "data"
    Project = var.project_name
  }
}