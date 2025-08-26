# Variables for Terraform AWS EKS Enterprise module

# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "eks-enterprise"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Cost center for billing purposes"
  type        = string
  default     = "Engineering"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Should be true to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Should be true to create a new VPN Gateway and attach it to the VPC"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}

# EKS Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster. If empty, will be generated from project_name and environment"
  type        = string
  default     = ""
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  validation {
    condition = alltrue([
      for log_type in var.cluster_enabled_log_types : contains([
        "api", "audit", "authenticator", "controllerManager", "scheduler"
      ], log_type)
    ])
    error_message = "Log types must be one of: api, audit, authenticator, controllerManager, scheduler."
  }
}

# Security Configuration
variable "enable_cluster_encryption" {
  description = "Enable envelope encryption of Kubernetes secrets using KMS"
  type        = bool
  default     = true
}

variable "kms_key_administrators" {
  description = "List of IAM ARNs for users/roles that can administer the KMS key"
  type        = list(string)
  default     = []
}

# Node Groups Configuration
variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default = {
    main = {
      desired_capacity = 3
      max_capacity     = 10
      min_capacity     = 1
      instance_types   = ["t3.medium"]
      capacity_type    = "ON_DEMAND"
      ami_type        = "AL2_x86_64"
      disk_size       = 20
    }
  }
}

variable "default_instance_types" {
  description = "Default instance types for node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "default_capacity_type" {
  description = "Default capacity type for node groups"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.default_capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}

variable "default_ami_type" {
  description = "Default AMI type for node groups"
  type        = string
  default     = "AL2_x86_64"
  validation {
    condition = contains([
      "AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64", "CUSTOM", "BOTTLEROCKET_ARM_64", "BOTTLEROCKET_x86_64"
    ], var.default_ami_type)
    error_message = "AMI type must be a valid EKS AMI type."
  }
}

variable "default_disk_size" {
  description = "Default disk size in GiB for worker nodes"
  type        = number
  default     = 20
  validation {
    condition     = var.default_disk_size >= 20 && var.default_disk_size <= 16384
    error_message = "Disk size must be between 20 and 16384 GiB."
  }
}

# Fargate Configuration
variable "fargate_profiles" {
  description = "Map of EKS Fargate Profile definitions to create"
  type        = any
  default     = {}
}

# Add-ons Configuration
variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster"
  type        = any
  default = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

# IRSA Configuration
variable "enable_irsa" {
  description = "Whether to create an OpenID Connect Provider for EKS to enable IRSA"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "enable_cloudwatch_logging" {
  description = "Enable CloudWatch logging for EKS"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention" {
  description = "Number of days to retain log events in CloudWatch"
  type        = number
  default     = 7
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_group_retention)
    error_message = "CloudWatch log group retention must be a valid value."
  }
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = false
}

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "monitoring"
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = false
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

# Application Configuration
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.6.2"
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler Helm chart"
  type        = string
  default     = "9.29.0"
}

variable "enable_ingress_nginx" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = false
}

variable "ingress_nginx_version" {
  description = "Version of NGINX Ingress Controller Helm chart"
  type        = string
  default     = "4.7.1"
}
