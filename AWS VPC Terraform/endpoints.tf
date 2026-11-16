# S3 GATEWAY ENDPOINT
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to the data route table (and private if you want private subnets to use it too)
  route_table_ids = [
    aws_route_table.data.id,
    aws_route_table.private[0].id,
    aws_route_table.private[1].id,
  ]

  tags = {
    Name    = "${var.project_name}-s3-endpoint"
    Project = var.project_name
  }
}

# DYNAMODB GATEWAY ENDPOINT
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.data.id,
    aws_route_table.private[0].id,
    aws_route_table.private[1].id,
  ]

  tags = {
    Name    = "${var.project_name}-dynamodb-endpoint"
    Project = var.project_name
  }
}