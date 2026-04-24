# Creates a production-grade simple AWS VPC in us-east-1 with DNS enabled, one public subnet and one private subnet in us-east-1a, an Internet Gateway, and separate route tables (public has default route to IGW; private has no NAT/egress route). All configurable values are exposed as variables and resources are tagged with Project=prateek plus standard tags.
# Generated Terraform code for AWS in us-east-1

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.25.0"
    }
  }
}

variable "availability_zone" {
  description = "Availability Zone to place the subnets in."
  type        = string
  default     = "us-east-1a"

  validation {
    condition     = can(regex("^us-east-1[a-z]$", var.availability_zone))
    error_message = "availability_zone must be a valid us-east-1 AZ (e.g., us-east-1a)."
  }
}

variable "environment" {
  description = "Environment name used for tagging and naming."
  type        = string
  default     = "prod"

  validation {
    condition     = length(var.environment) > 0
    error_message = "environment must not be empty."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "project" {
  description = "Project name used for tagging and naming."
  type        = string
  default     = "prateek"

  validation {
    condition     = length(var.project) > 0
    error_message = "project must not be empty."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = length(var.region) > 0
    error_message = "region must not be empty."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC."
  type        = bool
  default     = true
}

variable "vpc_enable_dns_support" {
  description = "Whether to enable DNS support in the VPC."
  type        = bool
  default     = true
}

variable "vpc_instance_tenancy" {
  description = "Instance tenancy option for the VPC."
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "dedicated", "host"], var.vpc_instance_tenancy)
    error_message = "vpc_instance_tenancy must be one of: default, dedicated, host."
  }
}

provider "aws" {
  region = var.region

  {{block_to_replace_cred}}
}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project
    },
    var.tags
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support
  instance_tenancy     = var.vpc_instance_tenancy

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-vpc"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  availability_zone       = var.availability_zone
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-subnet-public"
      Tier = "public"
    }
  )
}

resource "aws_subnet" "private" {
  availability_zone       = var.availability_zone
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-subnet-private"
      Tier = "private"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-rt-public"
    }
  )
}

resource "aws_route" "public_default" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
  route_table_id         = aws_route_table.public.id
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-rt-private"
    }
  )
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.id
}

output "availability_zone" {
  description = "Availability Zone used for the subnets."
  value       = var.availability_zone
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "private_route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}