variable cluster_name {}
variable "tags" {
  type = map
  default = {}
}
variable public_access {
    default = false
}

variable private_access {
    default = true
}

variable create_iamrole { 
  default = false
}

variable region {
    default = "us-west-2"
}
variable vpc_id {}

variable key_name {
  default = ""
}

data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}
variable "eks_version" {
  default = "1.15"
}
variable "admin_access_cidrs" {
  type = list(string)
  default = ["0.0.0.0/0"]
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    SubnetTier = "private"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "eksclusterRole" {
  count = var.create_iamrole == true ? 1: 0
  name = "eksclusterRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicyAttach" {
  count = var.create_iamrole == true ? 1: 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "eksclusterRole"
  depends_on = [ aws_iam_role.eksclusterRole ]
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicyAttach" {
  count = var.create_iamrole == true ? 1: 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "eksclusterRole"
  depends_on = [ aws_iam_role.eksclusterRole ]
}

resource "aws_eks_cluster" "ekscluster" {
  name     = var.cluster_name
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eksclusterRole"
  version  = var.eks_version
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  vpc_config {
    endpoint_private_access = var.private_access
    endpoint_public_access = var.public_access
    public_access_cidrs = var.admin_access_cidrs
    subnet_ids = data.aws_subnet_ids.private.ids
    security_group_ids = var.ssh_sg
  }
  lifecycle {
    create_before_destroy = false
  }

  depends_on = [ aws_cloudwatch_log_group.ekscluster ]
}

resource "aws_cloudwatch_log_group" "ekscluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  # ... potentially other configuration ...
}

# Fetch OIDC provider thumbprint for root CA
data "external" "thumbprint" {
  program = [ "${path.module}/oidc-thumbprint.sh", var.region ]
  depends_on = [ aws_eks_cluster.ekscluster ]
}

resource "aws_iam_openid_connect_provider" "ekscluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.ekscluster.identity.0.oidc.0.issuer
  depends_on = [ aws_eks_cluster.ekscluster ]
}


locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.ekscluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.ekscluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster_name}"
KUBECONFIG
}

output  eks_security_group_id {
    value = aws_eks_cluster.ekscluster.vpc_config.0.cluster_security_group_id
}
output "kubeconfig" {
  value = "${local.kubeconfig}"
}
