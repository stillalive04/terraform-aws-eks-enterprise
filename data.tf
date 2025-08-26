# Data sources for Terraform AWS EKS Enterprise

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get EKS cluster authentication token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Get the latest EKS optimized AMI
data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# Get the latest EKS optimized AMI for GPU instances
data "aws_ami" "eks_worker_gpu" {
  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${var.cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# Get the latest Bottlerocket AMI
data "aws_ami" "bottlerocket" {
  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${var.cluster_version}-x86_64-*"]
  }

  most_recent = true
  owners      = ["092701018744"] # Bottlerocket AMI Account ID
}

# Get AWS managed policy for EKS cluster service role
data "aws_iam_policy" "eks_cluster_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Get AWS managed policy for EKS worker node group
data "aws_iam_policy" "eks_worker_node_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Get AWS managed policy for EKS CNI
data "aws_iam_policy" "eks_cni_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Get AWS managed policy for EC2 container registry read only
data "aws_iam_policy" "ec2_container_registry_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Get AWS managed policy for EBS CSI driver
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Get AWS managed policy for EFS CSI driver
data "aws_iam_policy" "efs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# Get AWS managed policy for Fargate pod execution role
data "aws_iam_policy" "fargate_pod_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# Get AWS managed policy for AWS Load Balancer Controller
data "aws_iam_policy" "aws_load_balancer_controller" {
  arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# Get AWS managed policy for Cluster Autoscaler
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "clusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "clusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${local.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

# Get AWS Load Balancer Controller IAM policy
data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicy"
    effect = "Allow"

    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyUpdate"
    effect = "Allow"

    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DescribeSubscription",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyCreate"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]

    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:RequestedRegion"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyManage"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyTargetGroups"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]

    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyTags"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]

    resources = [
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
    ]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyDelete"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyEC2"
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AWSLoadBalancerControllerIAMPolicyEC2Tags"
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = ["arn:aws:ec2:*:*:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "Null"
      variable = "aws:RequestedRegion"
      values   = ["false"]
    }
  }
}

# Get current Kubernetes version information
data "aws_eks_addon_version" "latest" {
  for_each = var.cluster_addons

  addon_name         = each.key
  kubernetes_version = var.cluster_version
  most_recent        = try(each.value.most_recent, true)
}

# Get VPC endpoint service for EKS
data "aws_vpc_endpoint_service" "eks" {
  service = "eks"
}

# Get VPC endpoint service for EC2
data "aws_vpc_endpoint_service" "ec2" {
  service = "ec2"
}

# Get VPC endpoint service for ECR
data "aws_vpc_endpoint_service" "ecr_dkr" {
  service = "ecr.dkr"
}

data "aws_vpc_endpoint_service" "ecr_api" {
  service = "ecr.api"
}

# Get VPC endpoint service for S3
data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

# Get the latest AWS Systems Manager parameter for EKS optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/release_version"
}

# Get AWS partition information
data "aws_partition" "current" {}

# Get AWS DNS suffix
data "aws_dns_suffix" "current" {}
