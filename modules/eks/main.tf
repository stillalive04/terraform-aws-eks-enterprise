# EKS Cluster Module - Main Configuration
# This module creates an enterprise-grade EKS cluster with all necessary components

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_service_role_arn

  vpc_config {
    subnet_ids                     = var.subnet_ids
    endpoint_private_access        = var.cluster_endpoint_private_access
    endpoint_public_access         = var.cluster_endpoint_public_access
    public_access_cidrs           = var.cluster_endpoint_public_access_cidrs
    security_group_ids            = var.cluster_security_group_ids
  }

  # Logging configuration
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Encryption configuration
  dynamic "encryption_config" {
    for_each = var.cluster_encryption_config
    content {
      provider {
        key_arn = encryption_config.value.provider_key_arn
      }
      resources = encryption_config.value.resources
    }
  }

  # Ensure proper ordering of resource creation
  depends_on = [
    aws_cloudwatch_log_group.cluster
  ]

  tags = var.tags
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = var.tags
}

# EKS Cluster Security Group Rules
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count = var.cluster_endpoint_public_access && length(var.cluster_endpoint_public_access_cidrs) > 0 ? 1 : 0

  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.cluster_endpoint_public_access_cidrs
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# OIDC Provider for IRSA
data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-irsa"
    }
  )
}

# EKS Managed Node Groups
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = try(each.value.iam_role_arn, var.node_group_defaults.iam_role_arn)
  subnet_ids      = var.subnet_ids

  # Instance configuration
  instance_types = try(each.value.instance_types, var.node_group_defaults.instance_types, ["t3.medium"])
  capacity_type  = try(each.value.capacity_type, var.node_group_defaults.capacity_type, "ON_DEMAND")
  ami_type      = try(each.value.ami_type, var.node_group_defaults.ami_type, "AL2_x86_64")
  disk_size     = try(each.value.disk_size, var.node_group_defaults.disk_size, 20)

  # Scaling configuration
  scaling_config {
    desired_size = try(each.value.desired_capacity, each.value.desired_size, 3)
    max_size     = try(each.value.max_capacity, each.value.max_size, 10)
    min_size     = try(each.value.min_capacity, each.value.min_size, 1)
  }

  # Update configuration
  dynamic "update_config" {
    for_each = try(each.value.update_config, null) != null ? [each.value.update_config] : []
    content {
      max_unavailable_percentage = try(update_config.value.max_unavailable_percentage, null)
      max_unavailable           = try(update_config.value.max_unavailable, null)
    }
  }

  # Launch template configuration
  dynamic "launch_template" {
    for_each = try(each.value.launch_template, null) != null ? [each.value.launch_template] : []
    content {
      id      = try(launch_template.value.id, null)
      name    = try(launch_template.value.name, null)
      version = try(launch_template.value.version, "$Latest")
    }
  }

  # Remote access configuration
  dynamic "remote_access" {
    for_each = try(each.value.remote_access, null) != null ? [each.value.remote_access] : []
    content {
      ec2_ssh_key               = try(remote_access.value.ec2_ssh_key, null)
      source_security_group_ids = try(remote_access.value.source_security_group_ids, null)
    }
  }

  # Taints
  dynamic "taint" {
    for_each = try(each.value.taints, [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Labels
  labels = merge(
    try(each.value.k8s_labels, {}),
    try(each.value.labels, {}),
    {
      "node-group" = each.key
    }
  )

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = "${var.cluster_name}-${each.key}"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }
  )

  # Ensure proper ordering of resource creation
  depends_on = [
    aws_eks_cluster.this
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# EKS Fargate Profiles
resource "aws_eks_fargate_profile" "this" {
  for_each = var.fargate_profiles

  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = try(each.value.pod_execution_role_arn, var.fargate_pod_execution_role_arn)
  subnet_ids            = var.subnet_ids

  dynamic "selector" {
    for_each = try(each.value.selectors, [])
    content {
      namespace = selector.value.namespace
      labels    = try(selector.value.labels, {})
    }
  }

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )

  depends_on = [
    aws_eks_cluster.this
  ]
}

# EKS Add-ons
resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name             = aws_eks_cluster.this.name
  addon_name               = each.key
  addon_version            = try(each.value.addon_version, null)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, true)
  resolve_conflicts        = try(each.value.resolve_conflicts, "OVERWRITE")
  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.this
  ]
}

# EKS Identity Provider Config
resource "aws_eks_identity_provider_config" "this" {
  for_each = var.identity_providers

  cluster_name = aws_eks_cluster.this.name

  oidc {
    identity_provider_config_name = each.key
    issuer_url                   = each.value.issuer_url
    client_id                    = each.value.client_id
    username_claim               = try(each.value.username_claim, null)
    username_prefix              = try(each.value.username_prefix, null)
    groups_claim                 = try(each.value.groups_claim, null)
    groups_prefix                = try(each.value.groups_prefix, null)
    required_claims              = try(each.value.required_claims, {})
  }

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = "${var.cluster_name}-${each.key}"
    }
  )

  depends_on = [
    aws_eks_cluster.this
  ]
}

# Additional security group for worker nodes
resource "aws_security_group" "node_group_one" {
  count = var.create_node_security_group ? 1 : 0

  name_prefix = "${var.cluster_name}-node-group-"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  ingress {
    description     = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-group-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Security group rule to allow cluster control plane to communicate with worker nodes
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  count = var.create_node_security_group ? 1 : 0

  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group_one[0].id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
