# Fixes the security group egress rule validation error by configuring exactly one destination attribute (cidr_ipv4) for the VPC endpoint security group egress rule.
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

variable "availability_zones" {
  description = "Availability zones to use for subnets."
  type        = list(string)
  default     = ["us-east-1a"]

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "At least one availability zone must be provided."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "project_tag" {
  description = "Value for the Project tag."
  type        = string
  default     = "pra"
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
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

provider "aws" {
  {{block_to_replace_cred}}
  region = var.region
}

locals {
  tags = {
    ManagedBy = "terraform"
    Project   = var.project_tag
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = merge(local.tags, {
    Name = "pra-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-igw"
  })
}

resource "aws_subnet" "public" {
  availability_zone       = var.availability_zones[0]
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-subnet-public"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  availability_zone = var.availability_zones[0]
  cidr_block        = var.private_subnet_cidr
  vpc_id            = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-subnet-private"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "pra-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(local.tags, {
    Name = "pra-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-rt-public"
  })
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

  tags = merge(local.tags, {
    Name = "pra-rt-private"
  })
}

resource "aws_route" "private_default" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
  route_table_id         = aws_route_table.private.id
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.id
}

resource "aws_security_group" "vpce" {
  description = "Security group for Interface VPC Endpoints"
  name        = "pra-vpce"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-sg-vpce"
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https_from_vpc" {
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.vpce.id
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "vpce_all" {
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.vpce.id
}

resource "aws_vpc_endpoint" "s3" {
  route_table_ids   = [aws_route_table.private.id]
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-vpce-s3"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  route_table_ids   = [aws_route_table.private.id]
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  vpc_id            = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-vpce-dynamodb"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  service_name        = "com.amazonaws.${var.region}.ssm"
  subnet_ids          = [aws_subnet.private.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-vpce-ssm"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  subnet_ids          = [aws_subnet.private.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-vpce-ssmmessages"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  subnet_ids          = [aws_subnet.private.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "pra-vpce-ec2messages"
  })
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway (allocated via EIP)."
  value       = aws_eip.nat.public_ip
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_endpoint_ids" {
  description = "VPC Endpoint IDs created (S3, DynamoDB, SSM, SSMMessages, EC2Messages)."
  value = {
    dynamodb    = aws_vpc_endpoint.dynamodb.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
    s3          = aws_vpc_endpoint.s3.id
    ssm         = aws_vpc_endpoint.ssm.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
  }
}