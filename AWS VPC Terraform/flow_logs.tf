# S3 BUCKET FOR FLOW LOG ARCHIVE
resource "aws_s3_bucket" "flow_logs" {
  bucket        = "${var.project_name}-flow-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-flow-logs"
    Project = var.project_name
  }
}

# CLOUDWATCH LOG GROUP FOR REAL‑TIME MONITORING

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project_name}/flow-logs"
  retention_in_days = 90

  tags = {
    Name    = "${var.project_name}-flow-logs"
    Project = var.project_name
  }
}

# IAM ROLE FOR FLOW LOGS (CloudWatch)
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.project_name}-flow-logs-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "flow_logs_cloudwatch" {
  name = "${var.project_name}-flow-logs-cloudwatch"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

# FLOW LOG  →  CLOUDWATCH
resource "aws_flow_log" "cloudwatch" {
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = {
    Name    = "${var.project_name}-flow-log-cloudwatch"
    Project = var.project_name
  }
}

# FLOW LOG  →  S3  (long‑term archive)
resource "aws_flow_log" "s3" {
  log_destination      = aws_s3_bucket.flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-flow-log-s3"
    Project = var.project_name
  }
}