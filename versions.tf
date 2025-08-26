# Provider version constraints for Terraform AWS EKS Enterprise

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
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}
