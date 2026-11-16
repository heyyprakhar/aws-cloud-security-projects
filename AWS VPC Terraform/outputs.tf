output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "IDs of the data subnets"
  value       = aws_subnet.data[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.nat[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for the App tier"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group ID for the DB tier"
  value       = aws_security_group.db.id
}

output "flow_logs_cloudwatch_group" {
  description = "CloudWatch log group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "flow_logs_s3_bucket" {
  description = "S3 bucket for VPC Flow Logs archive"
  value       = aws_s3_bucket.flow_logs.bucket
}