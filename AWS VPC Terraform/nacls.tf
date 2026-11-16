# PUBLIC NACL  –  Allow 443 inbound, allow ephemeral return
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    from_port  = 0
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name    = "${var.project_name}-public-nacl"
    Project = var.project_name
  }
}

# PRIVATE NACL  –  Allow VPC traffic only
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = var.vpc_cidr
  }

  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }

  tags = {
    Name    = "${var.project_name}-private-nacl"
    Project = var.project_name
  }
}


# DATA NACL  –  Deny everything except VPC‑internal
resource "aws_network_acl" "data" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.data[*].id

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = var.vpc_cidr
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = var.vpc_cidr
  }

  tags = {
    Name    = "${var.project_name}-data-nacl"
    Project = var.project_name
  }
}