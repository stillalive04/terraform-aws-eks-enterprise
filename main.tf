# Main Terraform configuration for AWS EKS Enterprise
# This file orchestrates the deployment of all components

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# Data sources
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "terraform-aws-eks-enterprise"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  )

  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}-eks"
  
  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name                 = "${local.cluster_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = local.azs
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = var.enable_vpn_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs

  # Kubernetes tags for subnet discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"

  cluster_name = local.cluster_name
  environment  = var.environment
  
  # KMS configuration
  create_kms_key = var.enable_cluster_encryption
  kms_key_administrators = var.kms_key_administrators
  
  # IAM configuration
  create_cluster_service_role = true
  create_node_group_role     = true
  
  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Network configuration
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Security configuration
  cluster_service_role_arn = module.security.cluster_service_role_arn
  enable_cluster_encryption = var.enable_cluster_encryption
  cluster_encryption_config = var.enable_cluster_encryption ? [
    {
      provider_key_arn = module.security.kms_key_arn
      resources        = ["secrets"]
    }
  ] : []

  # Logging configuration
  cluster_enabled_log_types = var.cluster_enabled_log_types

  # Node groups
  node_groups = var.node_groups
  node_group_defaults = {
    instance_types = var.default_instance_types
    capacity_type  = var.default_capacity_type
    ami_type      = var.default_ami_type
    disk_size     = var.default_disk_size
    
    # IAM role
    iam_role_arn = module.security.node_group_role_arn
    
    # Security groups
    vpc_security_group_ids = [module.security.node_group_security_group_id]
  }

  # Fargate profiles
  fargate_profiles = var.fargate_profiles

  # Add-ons
  cluster_addons = var.cluster_addons

  # IRSA
  enable_irsa = var.enable_irsa

  tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  cluster_name = local.cluster_name
  environment  = var.environment

  # CloudWatch configuration
  enable_cloudwatch_logging = var.enable_cloudwatch_logging
  cloudwatch_log_group_retention = var.cloudwatch_log_group_retention

  # Prometheus configuration
  enable_prometheus = var.enable_prometheus
  prometheus_namespace = var.prometheus_namespace

  # Grafana configuration
  enable_grafana = var.enable_grafana
  grafana_admin_password = var.grafana_admin_password

  # Container Insights
  enable_container_insights = var.enable_container_insights

  # X-Ray
  enable_xray = var.enable_xray

  tags = local.common_tags

  depends_on = [module.eks]
}

# Additional Kubernetes resources
resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus || var.enable_grafana ? 1 : 0

  metadata {
    name = var.prometheus_namespace
    
    labels = {
      name = var.prometheus_namespace
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  metadata {
    name = "ingress-nginx"
    
    labels = {
      name = "ingress-nginx"
    }
  }

  depends_on = [module.eks]
}

# Helm releases for common applications
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_version

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks]
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version

  set {
    name  = "autoDiscovery.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  depends_on = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = var.ingress_nginx_version

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.ingress_nginx
  ]
}
