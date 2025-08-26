# Terraform AWS EKS Enterprise

[![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/stillalive04/terraform-aws-eks-enterprise)](https://github.com/stillalive04/terraform-aws-eks-enterprise/issues)
[![GitHub Stars](https://img.shields.io/github/stars/stillalive04/terraform-aws-eks-enterprise)](https://github.com/stillalive04/terraform-aws-eks-enterprise/stargazers)

A comprehensive Terraform module for deploying enterprise-grade Amazon EKS clusters with advanced security, monitoring, and operational capabilities.

## 🚀 Features

### 🏗️ Infrastructure as Code
- **Modular Architecture**: Reusable and composable Terraform modules
- **Multi-Environment Support**: Dev, staging, and production configurations
- **Best Practices**: Following AWS Well-Architected Framework principles

### 🔒 Enterprise Security
- **IAM Integration**: Fine-grained access control with RBAC
- **Network Security**: Private subnets, security groups, and NACLs
- **Encryption**: Data encryption at rest and in transit
- **Compliance**: SOC2, HIPAA, and PCI DSS ready configurations

### 📊 Observability & Monitoring
- **CloudWatch Integration**: Comprehensive logging and monitoring
- **Prometheus & Grafana**: Kubernetes-native observability stack
- **AWS X-Ray**: Distributed tracing capabilities
- **Cost Optimization**: Resource tagging and cost allocation

### ⚡ High Availability & Scalability
- **Multi-AZ Deployment**: Cross-availability zone redundancy
- **Auto Scaling**: Cluster and pod autoscaling capabilities
- **Load Balancing**: Application and Network Load Balancer integration
- **Disaster Recovery**: Backup and restore strategies

## 📋 Prerequisites

- **Terraform**: >= 1.5.0
- **AWS CLI**: >= 2.0.0
- **kubectl**: >= 1.24.0
- **Helm**: >= 3.8.0 (optional)
- **AWS Account**: With appropriate IAM permissions

## 🏃‍♂️ Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/stillalive04/terraform-aws-eks-enterprise.git
cd terraform-aws-eks-enterprise
```

### 2. Configure AWS Credentials

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Deployment

```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
```

### 5. Deploy the Infrastructure

```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 6. Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
```