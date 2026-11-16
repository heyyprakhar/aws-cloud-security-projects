variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Project name used for tagging and naming"
  type        = string
  default     = "vpc-iac"
}

variable "azs" {
  description = "Availability Zones to use"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}