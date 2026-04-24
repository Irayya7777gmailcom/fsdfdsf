# Change applied: updated the AWS provider region from var.region (default "eastus") to the literal "us-east-1" so the VPC and all related resources will be managed in us-east-1.
            # Modified Terraform Code for AWS in eastus

            terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.25.0"
    }
  }
}

            variable "availability_zones" {
  description = "Availability zones to use for subnets."
  type        = list(string)
  default     = ["eastus"]

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "availability_zones must contain at least one value."
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

variable "nat_gateway_private_ip" {
  description = "Requested private IPv4 address for the NAT Gateway (must be within the public subnet CIDR)."
  type        = string
  default     = "10.90.155.24"
}

variable "private_subnet_count" {
  description = "Number of private subnets to create (one per AZ in order)."
  type        = number
  default     = 1

  validation {
    condition     = var.private_subnet_count >= 1
    error_message = "private_subnet_count must be >= 1."
  }
}

variable "project" {
  description = "Project name used for tagging and naming."
  type        = string
  default     = "ssds"

  validation {
    condition     = length(var.project) > 0
    error_message = "project must not be empty."
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets to create (one per AZ in order)."
  type        = number
  default     = 1

  validation {
    condition     = var.public_subnet_count >= 1
    error_message = "public_subnet_count must be >= 1."
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eastus"

  validation {
    condition     = length(var.region) > 0
    error_message = "region must not be empty."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default = {
    Name = "ssds"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

            provider "aws" {
  # NOTE: Region updated per request. This will move ALL resources to us-east-1 on next apply.
  region = "us-east-1"
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

  private_subnet_cidrs = [for i in range(var.private_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  public_subnet_cidrs  = [for i in range(var.public_subnet_count) : cidrsubnet(var.vpc_cidr, 8, i)]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

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
  for_each = { for idx, cidr in local.public_subnet_cidrs : tostring(idx) => cidr }

  availability_zone       = data.aws_availability_zones.available.names[tonumber(each.key)]
  cidr_block              = each.value
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-subnet-public-${each.key}"
      Tier = "public"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in local.private_subnet_cidrs : tostring(idx) => cidr }

  availability_zone       = data.aws_availability_zones.available.names[tonumber(each.key)]
  cidr_block              = each.value
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-subnet-private-${each.key}"
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
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-eip-nat"
    }
  )
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  private_ip    = var.nat_gateway_private_ip
  subnet_id     = one(values(aws_subnet.public)).id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-nat"
    }
  )

  depends_on = [aws_internet_gateway.main]
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

resource "aws_route" "private_default" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
  route_table_id         = aws_route_table.private.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  route_table_id = aws_route_table.private.id
  subnet_id      = each.value.id
}

resource "aws_security_group" "vpce" {
  description = "Security group for VPC interface endpoints"
  name        = "${var.project}-${var.environment}-vpce"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-sg-vpce"
    }
  )
}

resource "aws_vpc_endpoint" "dsa" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  service_name        = "dsa"
  subnet_ids          = [for s in values(aws_subnet.private) : s.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-vpce-dsa"
    }
  )
}

            output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = [for s in values(aws_subnet.private) : s.id]
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = [for s in values(aws_subnet.public) : s.id]
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_endpoint_id_dsa" {
  description = "ID of the VPC Endpoint named 'dsa'."
  value       = aws_vpc_endpoint.dsa.id
}