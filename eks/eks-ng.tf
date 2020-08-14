
#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
# 
variable "ngname_prefix" {
  default = ""
}
variable "azno" {
  default = 2
}
variable "nodegroup_config" {
      type = map(string)
      default = {
        custom_activity_nodegroup = true
        managed_access_nodegroup = true
        managed_activity_nodegroup = false
        custom_access_nodegroup = false
        analytics_nodegroup = false
      }
}

variable access_labels {
  type = map(string)
  default = {
    app = "prometheus"
  }
}
variable ssh_sg {
  type = list
  default = []
}

variable "activity_disk_size" {
  default = 128
}

variable "analytics_disk_size" {
  default = 128
}

variable "access_disk_size" {
  default = 128
}
variable "eks_release_version" {
  default = "1.15.10-20200228"
}

variable access_instance_types {
  type = list(string)
  default = [ "m5.large" ]
}

variable analytics_max_size {
  default = 5
}

variable analytics_min_size {
  default = 1
}

variable analytics_desired_size {
  default = 1
}

variable analytics_instance_types {
  type = list(string)
  default = [ "t3.medium" ]
}

variable activity_max_size {
  default = 25
}

variable "activity_desired_size" {
  default = 1
}

variable activity_min_size {
  default = 1
}

variable activity_instance_types {
  type = list(string)
  default = [ "m5.xlarge", "m5.2xlarge" , "c5.xlarge" , "c5.2xlarge" ]
}

resource "aws_eks_node_group" "access-nodeport" {
  count           =  (var.nodegroup_config["managed_access_nodegroup"] ? 1 : 0)
  cluster_name    = aws_eks_cluster.ekscluster.name
  node_group_name = "${var.ngname_prefix}prometheus"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eksnode"
  instance_types  = var.access_instance_types
  subnet_ids      = [tolist(data.aws_subnet_ids.private.ids)[var.azno]]
  version         = var.eks_version
  release_version = var.eks_release_version  # must lock version & release_version for production
  labels          = var.access_labels
  disk_size       = var.access_disk_size

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key     = var.key_name
    source_security_group_ids = var.ssh_sg
  }

  tags = merge(var.tags,
      map("Name","prometheus")
  )
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eksnode_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksnode_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksnode_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role.eksnode,
    aws_eks_cluster.ekscluster
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "analytics" {
  count           =  (var.nodegroup_config["analytics_nodegroup"] ? length(data.aws_subnet_ids.private.ids) : 0)
  cluster_name    = aws_eks_cluster.ekscluster.name
  node_group_name = "${var.ngname_prefix}analytics-${count.index}"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eksnode"
  ami_type        =  "AL2_x86_64_GPU"  # For GPU
  instance_types  =  var.analytics_instance_types
  disk_size       = var.analytics_disk_size
  subnet_ids      = [tolist(data.aws_subnet_ids.private.ids)[count.index]]
  version         = var.eks_version
  release_version = var.eks_release_version  # must lock version & release_version for production

  remote_access {
    ec2_ssh_key     = var.key_name
    source_security_group_ids = var.ssh_sg
  }
  scaling_config {
    desired_size = var.analytics_desired_size
    max_size     = var.analytics_max_size
    min_size     = var.analytics_min_size
  }

  tags = merge(var.tags,
      map("Name","analytics-${count.index}")
  )

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eksnode_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksnode_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksnode_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role.eksnode,
    aws_eks_cluster.ekscluster
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ scaling_config["desired_size"] ]
  }
}

resource "aws_eks_node_group" "activity" {
  count           =  (var.nodegroup_config["managed_activity_nodegroup"] ? length(data.aws_subnet_ids.private.ids) : 0)
  cluster_name    = aws_eks_cluster.ekscluster.name
  node_group_name = "${var.ngname_prefix}activity-${count.index}"
  node_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eksnode"
  subnet_ids      = [tolist(data.aws_subnet_ids.private.ids)[count.index]]
  version         = var.eks_version
  release_version = var.eks_release_version  # must lock version & release_version for production
  instance_types  = var.activity_instance_types
  disk_size       = var.activity_disk_size
  scaling_config {
    desired_size = var.activity_desired_size
    max_size     = var.activity_max_size
    min_size     = var.activity_min_size
  }

  tags = merge(var.tags,
      map("Name","activity-${count.index}")
  )

  remote_access {
    ec2_ssh_key     = var.key_name
    source_security_group_ids = var.ssh_sg
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eksnode_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksnode_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksnode_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role.eksnode,
    aws_eks_cluster.ekscluster
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ scaling_config[ "desired_size" ] ]
  }
}
