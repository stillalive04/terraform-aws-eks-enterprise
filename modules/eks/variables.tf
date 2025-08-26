# Variables for EKS Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the cluster will be deployed"
  type        = list(string)
}

variable "cluster_service_role_arn" {
  description = "ARN of the IAM role that provides permissions for the Kubernetes control plane"
  type        = string
}

# Cluster Endpoint Configuration
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

variable "cluster_security_group_ids" {
  description = "List of security group IDs for the cross-account elastic network interfaces"
  type        = list(string)
  default     = []
}

# Logging Configuration
variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_group_retention" {
  description = "Number of days to retain log events in CloudWatch"
  type        = number
  default     = 7
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data"
  type        = string
  default     = null
}

# Encryption Configuration
variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster"
  type = list(object({
    provider_key_arn = string
    resources        = list(string)
  }))
  default = []
}

# IRSA Configuration
variable "enable_irsa" {
  description = "Whether to create an OpenID Connect Provider for EKS to enable IRSA"
  type        = bool
  default     = true
}

# Node Groups Configuration
variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default     = {}
}

variable "node_group_defaults" {
  description = "Map of EKS managed node group default configurations"
  type        = any
  default = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    ami_type      = "AL2_x86_64"
    disk_size     = 20
  }
}

variable "create_node_security_group" {
  description = "Whether to create a security group for the node groups"
  type        = bool
  default     = true
}

# Fargate Configuration
variable "fargate_profiles" {
  description = "Map of EKS Fargate Profile definitions to create"
  type        = any
  default     = {}
}

variable "fargate_pod_execution_role_arn" {
  description = "ARN of the IAM role that provides permissions for the Fargate pods"
  type        = string
  default     = null
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

# Identity Provider Configuration
variable "identity_providers" {
  description = "Map of cluster identity provider configurations to enable for the cluster"
  type        = any
  default     = {}
}

# Tags
variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
