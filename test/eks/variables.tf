variable vpc_id {
    type = map(string)
    default = {
        ops = "vpc-08097bee14c504087"
    }
}
variable key_pair {
    type = map(string)
    default = {
        ops = "ops-keypair"
    }
}
variable cluster_name {
    type = map(string)
    default = {
        ops = "ops-eks1"
    }
}

variable "eks_release_version" {
    type = map(string)
    default = {
        ops = "1.15.11-20200507"
    }
}

variable "create_iamrole" {
    type = map(bool)
    default = {
        ops = false
    }
}

variable "nodegroup_config" {
      type = map(string)
      default = {
        custom_activity_nodegroup = true
        managed_activity_nodegroup = false
        managed_access_nodegroup = true
        custom_access_nodegroup = false
        analytics_nodegroup = false
      }
}
