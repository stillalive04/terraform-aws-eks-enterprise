# Local values for Terraform AWS EKS Enterprise

locals {
  # Common tags applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "terraform-aws-eks-enterprise"
      Owner       = var.owner
      CostCenter  = var.cost_center
      CreatedAt   = formatdate("YYYY-MM-DD", timestamp())
    }
  )

  # Cluster name generation
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}-eks"
  
  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
  
  # Region-specific configurations
  region_config = {
    us-east-1 = {
      nat_gateway_count = var.enable_nat_gateway ? length(local.azs) : 0
      flow_logs_s3_arn = "arn:aws:s3:::aws-logs-${data.aws_caller_identity.current.account_id}-us-east-1"
    }
    us-west-2 = {
      nat_gateway_count = var.enable_nat_gateway ? length(local.azs) : 0
      flow_logs_s3_arn = "arn:aws:s3:::aws-logs-${data.aws_caller_identity.current.account_id}-us-west-2"
    }
    eu-west-1 = {
      nat_gateway_count = var.enable_nat_gateway ? length(local.azs) : 0
      flow_logs_s3_arn = "arn:aws:s3:::aws-logs-${data.aws_caller_identity.current.account_id}-eu-west-1"
    }
  }
  
  # Environment-specific configurations
  environment_config = {
    dev = {
      node_group_min_size = 1
      node_group_max_size = 5
      node_group_desired_size = 2
      enable_detailed_monitoring = false
      backup_retention_days = 7
    }
    staging = {
      node_group_min_size = 2
      node_group_max_size = 10
      node_group_desired_size = 3
      enable_detailed_monitoring = true
      backup_retention_days = 14
    }
    prod = {
      node_group_min_size = 3
      node_group_max_size = 20
      node_group_desired_size = 5
      enable_detailed_monitoring = true
      backup_retention_days = 30
    }
  }
  
  # Current environment configuration
  current_env_config = lookup(local.environment_config, var.environment, local.environment_config["dev"])
  
  # Security configurations
  security_config = {
    # Allowed instance types per environment
    allowed_instance_types = {
      dev = ["t3.micro", "t3.small", "t3.medium"]
      staging = ["t3.medium", "t3.large", "m5.large"]
      prod = ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge"]
    }
    
    # Network ACL rules
    network_acl_rules = {
      ingress = [
        {
          rule_number = 100
          protocol    = "tcp"
          rule_action = "allow"
          port_range = {
            from = 80
            to   = 80
          }
          cidr_block = "0.0.0.0/0"
        },
        {
          rule_number = 110
          protocol    = "tcp"
          rule_action = "allow"
          port_range = {
            from = 443
            to   = 443
          }
          cidr_block = "0.0.0.0/0"
        }
      ]
      egress = [
        {
          rule_number = 100
          protocol    = "-1"
          rule_action = "allow"
          cidr_block  = "0.0.0.0/0"
        }
      ]
    }
  }
  
  # Monitoring configurations
  monitoring_config = {
    cloudwatch_log_groups = [
      "/aws/eks/${local.cluster_name}/cluster",
      "/aws/containerinsights/${local.cluster_name}/application",
      "/aws/containerinsights/${local.cluster_name}/dataplane",
      "/aws/containerinsights/${local.cluster_name}/host",
      "/aws/containerinsights/${local.cluster_name}/performance"
    ]
    
    metric_filters = [
      {
        name           = "ErrorCount"
        pattern        = "ERROR"
        metric_name    = "ErrorCount"
        metric_namespace = "EKS/Cluster"
        default_value  = 0
      },
      {
        name           = "WarningCount"
        pattern        = "WARN"
        metric_name    = "WarningCount"
        metric_namespace = "EKS/Cluster"
        default_value  = 0
      }
    ]
  }
  
  # Application configurations
  application_config = {
    # Default resource limits
    default_resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    
    # Common labels for applications
    app_labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "app.kubernetes.io/part-of"    = local.cluster_name
      "app.kubernetes.io/version"    = var.cluster_version
    }
  }
  
  # Backup configurations
  backup_config = {
    enabled = var.environment == "prod" ? true : false
    schedule = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
    retention_period = local.current_env_config.backup_retention_days
    
    backup_vault_name = "${local.cluster_name}-backup-vault"
    backup_plan_name  = "${local.cluster_name}-backup-plan"
  }
  
  # Cost optimization configurations
  cost_config = {
    # Spot instance configurations
    spot_instance_config = {
      max_price = "0.05"  # Maximum price per hour
      interruption_behavior = "terminate"
      spot_type = "one-time"
    }
    
    # Auto-scaling configurations
    autoscaling_config = {
      scale_down_delay_after_add = "10m"
      scale_down_unneeded_time = "10m"
      skip_nodes_with_local_storage = false
      skip_nodes_with_system_pods = false
    }
  }
  
  # Compliance configurations
  compliance_config = {
    # Required tags for compliance
    compliance_tags = {
      "Compliance:SOC2"   = "true"
      "Compliance:HIPAA"  = var.environment == "prod" ? "true" : "false"
      "Compliance:PCI"    = var.environment == "prod" ? "true" : "false"
      "DataClassification" = var.environment == "prod" ? "Confidential" : "Internal"
    }
    
    # Security policies
    security_policies = {
      enforce_https = true
      require_encryption = var.enable_cluster_encryption
      network_policies_enabled = true
      pod_security_standards = "restricted"
    }
  }
}
