# ELASTIC IPs FOR NAT GATEWAYS
resource "aws_eip" "nat" {
  count = length(var.azs)

  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${var.azs[count.index]}"
    Project = var.project_name
  }
}
# NAT GATEWAYS  (in public subnets)
resource "aws_nat_gateway" "nat" {
  count = length(var.azs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "${var.project_name}-nat-${var.azs[count.index]}"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.igw]
}