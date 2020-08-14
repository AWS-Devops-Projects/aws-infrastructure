variable "on_demand_instance_percentage" {
  description = "on_demand instances_distribution percentage"
  default = 0
}
variable "activity_custom_min_size" {
  default = 0
}
variable "activity_custom_max_size" {
  default = 100
}
variable "activity_custom_desired_size" {
  default = 0
}
variable "autoscale_max_size" {
  default = 100
}
variable "autoscale_min_size" {
  default = 0
}
variable "autoscale_desired_size" {
  default = 0
}
variable "spot_max_price" {
  default = 0.99
}

variable max_instance_lifetime {
  default = 0
}

locals {
  sncount = length(data.aws_subnet_ids.private.ids)
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_version}-*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon Account ID
}

locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash -xe
/sbin/sysctl -w net.ipv4.ip_local_port_range="32768 60999"
/sbin/sysctl -w net.ipv4.ip_local_reserved_ports="30000-32767"

# Install kubectl
curl -m 30 -LO https://storage.googleapis.com/kubernetes-release/release/`curl -m 30 -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
mv kubectl /usr/local/bin/
chmod 755 /usr/local/bin/kubectl
if [ $? -ne 0 ]; then
    echo >&2 "Error installing kubectl."
    exit 5
fi

# check that aws and ec2-metadata commands are installed
command -v aws >/dev/null 2>&1 || { echo >&2 'aws command not installed.'; exit 2; }
command -v ec2-metadata >/dev/null 2>&1 || { echo >&2 'ec2-metadata command not installed.'; exit 3; }

# command alias
shopt -s expand_aliases
alias kubectlcfg="/usr/local/bin/kubectl --kubeconfig=/var/lib/kubelet/kubeconfig"
 
# set filter parameters
instanceId=$(ec2-metadata -i | cut -d ' ' -f2)
hostId=$(ec2-metadata -h | cut -d ' ' -f2)
 
# get region
region=$(ec2-metadata --availability-zone | cut -d ' ' -f2|sed -e 's/.$//')
 
# retrieve tags
tagValues=$(aws ec2 describe-tags --output text --region "$region" --filters "Name=key,Values=Name" "Name=resource-type,Values=instance" "Name=resource-id,Values=$instanceId")
if [ $? -ne 0 ]; then
    echo >&2 "Error retrieving tag value."
    exit 4
fi
 
# extract required tag value
tagValue=$(echo "$tagValues" | cut -f5|sed -e "s/${var.cluster_name}-//")
echo "$tagValue"

#  Assign NodeLabel
kubelet_args="--node-labels=eks.amazonaws.com/nodegroup=$tagValue"

if [[ $tagValue =~ .*prometheus.* ]]; then
    kubelet_args="--node-labels=eks.amazonaws.com/nodegroup=$tagValue,app=prometheus --register-with-taints=app=prometheus:NoSchedule"
fi

if [[ $tagValue =~ .*autoscale.* ]]; then
    kubelet_args="--node-labels=eks.amazonaws.com/nodegroup=$tagValue,type=autoscale --register-with-taints=type=autoscale:NoSchedule"
fi
echo "/etc/eks/bootstrap.sh ${var.cluster_name} --kubelet-extra-args '$kubelet_args'" | bash -xe
USERDATA
}

resource "aws_iam_instance_profile" "eks-nodegroup" {
  name = "${var.cluster_name}-eksnode"
  role = "${var.cluster_name}-eksnode"
}

resource "aws_autoscaling_group" "access" {
  count              =  (var.nodegroup_config["custom_access_nodegroup"] ? 1 : 0)
  desired_capacity     = 1
  max_size             = 1
  min_size             = 1
  name_prefix          = "${var.cluster_name}-access"

  health_check_type   = "EC2"
  ## Incase of instance failure or restart, ensurece new node comes up in the same region
  vpc_zone_identifier = [ element(tolist(data.aws_subnet_ids.private.ids),0) ]  
  enabled_metrics = ["GroupTerminatingCapacity", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupStandbyCapacity", "GroupTotalCapacity", "GroupDesiredCapacity", "GroupTerminatingInstances", "GroupTotalInstances", "GroupMaxSize", "GroupStandbyInstances", "GroupInServiceInstances", "GroupMinSize", "GroupPendingInstances" ]
  health_check_grace_period = 10
  max_instance_lifetime = var.max_instance_lifetime
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.activity.id
        version = "$Latest"
      }
      override {
        instance_type     = var.activity_instance_types[0%length(var.activity_instance_types)]
      }
    }
  }
  tag {
      key = "kubernetes.io/cluster/${var.cluster_name}"
      value = "owned"
      propagate_at_launch = true
    }

  tag {
      key = "app"
      value = "prometheus"
      propagate_at_launch = true
    }

  tag {
      key = "Name"
      value = "${var.cluster_name}-prometheus"
      propagate_at_launch = true
  }

  depends_on = [
    aws_eks_node_group.access-nodeport,
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

resource "aws_autoscaling_group" "activity" {
  count              =  (var.nodegroup_config["custom_activity_nodegroup"] ? (2 * local.sncount) : 0)
  min_size           = count.index < local.sncount ? var.activity_custom_min_size : var.autoscale_min_size
  max_size           = count.index < local.sncount ? var.activity_custom_max_size : var.autoscale_max_size
  desired_capacity   = count.index < local.sncount ? var.activity_custom_desired_size : var.autoscale_desired_size
  name_prefix        = (count.index < local.sncount? "${var.cluster_name}-activity-${count.index}-" : "${var.cluster_name}-autoscale-${count.index}-" )

  enabled_metrics = ["GroupTerminatingCapacity", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupStandbyCapacity", "GroupTotalCapacity", "GroupDesiredCapacity", "GroupTerminatingInstances", "GroupTotalInstances", "GroupMaxSize", "GroupStandbyInstances", "GroupInServiceInstances", "GroupMinSize", "GroupPendingInstances" ]
  health_check_grace_period = 10
  max_instance_lifetime = var.max_instance_lifetime

  health_check_type   = "EC2"

  mixed_instances_policy {

    instances_distribution {
        spot_max_price = var.spot_max_price
        spot_instance_pools = 4
        on_demand_percentage_above_base_capacity = var.on_demand_instance_percentage
    }
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.activity.id
        version = "$Latest"
      }
      override {
        instance_type     = var.activity_instance_types[0%length(var.activity_instance_types)]
      }

      override {
        instance_type     = var.activity_instance_types[1%length(var.activity_instance_types)]
      }

      override {
        instance_type     = var.activity_instance_types[2%length(var.activity_instance_types)]
      }

      override {
        instance_type     = var.activity_instance_types[3%length(var.activity_instance_types)]
      }
    }
  }
  vpc_zone_identifier = [ element(tolist(data.aws_subnet_ids.private.ids),(count.index % local.sncount)) ]

  tag {
      key = "k8s.io/cluster-autoscaler/node-template/label/type"
      value = (count.index < local.sncount ? "static" : "autoscale" )
      propagate_at_launch = true
    }

  tag {
      key = "k8s.io/cluster-autoscaler/node-template/taint/type"
      value = (count.index < local.sncount ? "None" : "autoscale:NoSchedule" )
      propagate_at_launch = true
    }

  tag {
      key = "kubernetes.io/cluster/${var.cluster_name}"
      value = "owned"
      propagate_at_launch = true
    }

  tag {
      key = "Name"
      value = (count.index < local.sncount? "${var.cluster_name}-activity-${count.index}" : "${var.cluster_name}-autoscale-${count.index}" )
      propagate_at_launch = true
  }

  tag {
      key = "k8s.io/cluster-autoscaler/enabled"
      value = true
      propagate_at_launch = true
  }

  tag {
      key = "k8s.io/cluster-autoscaler/${var.cluster_name}"
      value = "owned"
      propagate_at_launch = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eksnode_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eksnode_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eksnode_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role.eksnode,
    aws_eks_cluster.ekscluster
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ desired_capacity ]
  }
}

resource "aws_launch_template" "activity" {
  name_prefix                 = "activity"
  description                 = "custom eks activity nodegroup"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.activity_disk_size
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  ebs_optimized = true

  image_id  = data.aws_ami.eks-worker.id
  iam_instance_profile  {
    name = aws_iam_instance_profile.eks-nodegroup.name
  }

  instance_initiated_shutdown_behavior = "terminate"

  instance_type     = var.activity_instance_types[0%length(var.activity_instance_types)]
  key_name                    = var.key_name

  vpc_security_group_ids = concat(var.ssh_sg, [aws_eks_cluster.ekscluster.vpc_config.0.cluster_security_group_id])

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "lt-nodegroup-${var.cluster_name}"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  user_data  = base64encode(local.eks-node-userdata)
}