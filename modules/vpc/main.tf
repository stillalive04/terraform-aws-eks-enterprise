# VPC Module for EKS - Main Configuration
# This module creates a VPC optimized for EKS workloads

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = var.name
    },
    var.vpc_tags
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  count = var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-igw"
    },
    var.igw_tags
  )

  depends_on = [aws_vpc.this]
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = element(concat(var.public_subnets, [""]), count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-public-%s", element(var.azs, count.index))
      Type = "Public"
    },
    var.public_subnet_tags
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = element(concat(var.private_subnets, [""]), count.index)
  availability_zone = element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-private-%s", element(var.azs, count.index))
      Type = "Private"
    },
    var.private_subnet_tags
  )
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(var.database_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = element(concat(var.database_subnets, [""]), count.index)
  availability_zone = element(var.azs, count.index)

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-db-%s", element(var.azs, count.index))
      Type = "Database"
    },
    var.database_subnet_tags
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-nat-%s", element(var.azs, var.single_nat_gateway ? 0 : count.index))
    },
    var.nat_eip_tags
  )

  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0

  allocation_id = element(aws_eip.nat[*].id, var.single_nat_gateway ? 0 : count.index)
  subnet_id     = element(aws_subnet.public[*].id, var.single_nat_gateway ? 0 : count.index)

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-nat-%s", element(var.azs, var.single_nat_gateway ? 0 : count.index))
    },
    var.nat_gateway_tags
  )

  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-public"
      Type = "Public"
    },
    var.public_route_table_tags
  )
}

# Public Routes
resource "aws_route" "public_internet_gateway" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = format("${var.name}-private-%s", element(var.azs, count.index))
      Type = "Private"
    },
    var.private_route_table_tags
  )
}

# Private Routes (NAT Gateway)
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? length(var.private_subnets) : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, var.single_nat_gateway ? 0 : count.index)

  timeouts {
    create = "5m"
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

# Database Route Table
resource "aws_route_table" "database" {
  count = length(var.database_subnets) > 0 ? (var.create_database_subnet_route_table ? 1 : 0) : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-database"
      Type = "Database"
    },
    var.database_route_table_tags
  )
}

# Database Route Table Associations
resource "aws_route_table_association" "database" {
  count = length(var.database_subnets) > 0 ? (var.create_database_subnet_route_table ? length(var.database_subnets) : 0) : 0

  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database[0].id
}

# Database Subnet Group
resource "aws_db_subnet_group" "database" {
  count = length(var.database_subnets) > 0 && var.create_database_subnet_group ? 1 : 0

  name        = lower("${var.name}-database")
  description = "Database subnet group for ${var.name}"
  subnet_ids  = aws_subnet.database[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-database"
    },
    var.database_subnet_group_tags
  )
}

# VPN Gateway
resource "aws_vpn_gateway" "this" {
  count = var.enable_vpn_gateway ? 1 : 0

  vpc_id          = aws_vpc.this.id
  amazon_side_asn = var.amazon_side_asn

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-vpn-gateway"
    },
    var.vpn_gateway_tags
  )
}

# VPN Gateway Route Propagation
resource "aws_vpn_gateway_route_propagation" "public" {
  count = var.propagate_public_route_tables_vgw && var.enable_vpn_gateway && length(var.public_subnets) > 0 ? 1 : 0

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count = var.propagate_private_route_tables_vgw && var.enable_vpn_gateway ? length(var.private_subnets) : 0

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  count = var.enable_flow_log ? 1 : 0

  iam_role_arn    = var.create_flow_log_cloudwatch_iam_role ? aws_iam_role.flow_log[0].arn : var.flow_log_cloudwatch_iam_role_arn
  log_destination = var.create_flow_log_cloudwatch_log_group ? aws_cloudwatch_log_group.flow_log[0].arn : var.flow_log_cloudwatch_log_group_arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-flow-log"
    }
  )
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_log && var.create_flow_log_cloudwatch_log_group ? 1 : 0

  name              = "${var.name}-vpc-flow-log"
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
  kms_key_id        = var.flow_log_cloudwatch_log_group_kms_key_id

  tags = var.tags
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log && var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name               = "${var.name}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_cloudwatch_assume_role[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "flow_log_cloudwatch_assume_role" {
  count = var.enable_flow_log && var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  statement {
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM Role Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log && var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name   = "${var.name}-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log_cloudwatch[0].json
}

data "aws_iam_policy_document" "flow_log_cloudwatch" {
  count = var.enable_flow_log && var.create_flow_log_cloudwatch_iam_role ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

# VPC Endpoints
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-s3-endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.name}-dynamodb-endpoint"
    }
  )
}

# VPC Endpoint Route Table Associations
resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count = var.enable_s3_endpoint ? length(aws_route_table.private) : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  count = var.enable_s3_endpoint && length(aws_route_table.public) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.public[0].id
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_private" {
  count = var.enable_dynamodb_endpoint ? length(aws_route_table.private) : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_public" {
  count = var.enable_dynamodb_endpoint && length(aws_route_table.public) > 0 ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = aws_route_table.public[0].id
}
