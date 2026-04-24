# Creates a single production-grade AWS VPC (only the VPC resource) in us-east-1 with DNS support/hostnames enabled and consistent tagging. CIDR is configurable via variables. Suitable for Git push after plan (no backend or extra resources included).
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

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC (IPv4)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "vpc_cidr_block must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "vpc_enable_dns_hostnames" {
  description = "Whether instances launched in the VPC get DNS hostnames."
  type        = bool
  default     = true
}

variable "vpc_enable_dns_support" {
  description = "Whether the VPC supports DNS resolution through the Amazon-provided DNS server."
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Name tag value for the VPC."
  type        = string
  default     = "main"

  validation {
    condition     = length(var.vpc_name) > 0
    error_message = "vpc_name must not be empty."
  }
}

provider "aws" {
  {{block_to_replace_cred}}

  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    }
  )
}

output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the created VPC."
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the created VPC."
  value       = aws_vpc.main.cidr_block
}