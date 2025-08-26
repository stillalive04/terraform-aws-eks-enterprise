# Outputs for EKS Module

# Cluster Information
output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.this.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.this.status
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-group/${aws_eks_cluster.this.vpc_config[0].cluster_security_group_id}"
}

output "cluster_created_at" {
  description = "Unix epoch timestamp in seconds for when the cluster was created"
  value       = aws_eks_cluster.this.created_at
}

# OIDC Provider
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = try(aws_iam_openid_connect_provider.cluster[0].arn, null)
}

output "cluster_tls_certificate_sha1_fingerprint" {
  description = "The SHA1 fingerprint of the public key of the cluster's certificate"
  value       = try(data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint, null)
}

# Node Groups
output "node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = aws_eks_node_group.this
  sensitive   = true
}

output "node_group_arns" {
  description = "List of the EKS managed node group ARNs"
  value       = values(aws_eks_node_group.this)[*].arn
}

output "node_group_status" {
  description = "Status of the EKS managed node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.status }
}

output "node_group_remote_access_security_group_id" {
  description = "Identifier of the remote access EC2 Security Group"
  value       = { for k, v in aws_eks_node_group.this : k => try(v.remote_access[0].source_security_group_ids[0], null) }
}

output "node_group_resources" {
  description = "List of objects containing information about underlying resources of EKS managed node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.resources }
}

output "node_group_asg_names" {
  description = "List of the autoscaling group names"
  value = {
    for k, v in aws_eks_node_group.this : k => try(v.resources[0].autoscaling_groups[*].name, [])
  }
}

# Fargate Profiles
output "fargate_profiles" {
  description = "Map of attribute maps for all EKS Fargate Profiles created"
  value       = aws_eks_fargate_profile.this
}

output "fargate_profile_arns" {
  description = "Amazon Resource Name (ARN) of the EKS Fargate Profiles"
  value       = values(aws_eks_fargate_profile.this)[*].arn
}

output "fargate_profile_status" {
  description = "Status of the EKS Fargate Profiles"
  value       = { for k, v in aws_eks_fargate_profile.this : k => v.status }
}

# Add-ons
output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = aws_eks_addon.this
}

output "cluster_addon_arns" {
  description = "Map of Amazon Resource Name (ARN) of the EKS add-ons"
  value       = { for k, v in aws_eks_addon.this : k => v.arn }
}

output "cluster_addon_status" {
  description = "Status of EKS add-ons"
  value       = { for k, v in aws_eks_addon.this : k => v.status }
}

# Identity Provider
output "identity_provider_config_arns" {
  description = "Amazon Resource Name (ARN) of the EKS Identity Provider Configurations"
  value       = values(aws_eks_identity_provider_config.this)[*].arn
}

output "identity_provider_config_status" {
  description = "Status of the EKS Identity Provider Configurations"
  value       = { for k, v in aws_eks_identity_provider_config.this : k => v.status }
}

# Security Groups
output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = try(aws_security_group.node_group_one[0].id, null)
}

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = try(aws_security_group.node_group_one[0].arn, null)
}

# CloudWatch
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.cluster.arn
}

# Cluster Configuration
output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_service_cidr" {
  description = "The CIDR block that Kubernetes pod and service IP addresses are assigned from"
  value       = aws_eks_cluster.this.kubernetes_network_config[0].service_ipv4_cidr
}

output "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses"
  value       = aws_eks_cluster.this.kubernetes_network_config[0].ip_family
}
