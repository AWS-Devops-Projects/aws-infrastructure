module "create-eks-cluster" {

    source  = "../../../terraform/modules/eks_cluster"
    #source  = "https://github.com/SamsonGudise/aws-infrastructure.git/eks_cluster?ref=v0.1.001"
    vpc_id = var.vpc_id[terraform.workspace]
    key_name = var.key_pair[terraform.workspace]
    region = "us-west-2"
    cluster_name = var.cluster_name[terraform.workspace]
    public_access = true
    private_access = true
    create_iamrole = var.create_iamrole[terraform.workspace]
    access_instance_types = ["m5.large"]
    env = terraform.workspace
    eks_version = 1.15
    eks_release_version = "1.15.11-20200609"
    workspace_iam_roles = var.workspace_iam_roles
    ssh_sg = data.aws_security_groups.ssh_security_group.ids
    nodegroup_config = var.nodegroup_config
    ngname_prefix="v1"
    delay_in_seconds=30
}

data aws_security_groups "ssh_security_group" {
    filter {
        name   = "vpc-id"
        values = [ var.vpc_id[terraform.workspace] ]
    }
    filter {
        name = "tag:Name"
        values = [ "ssh_admin_access", "access_nodeport"]
    }
}

output  "eks-kubeconfig" {
    value = "${module.create-eks-cluster.kubeconfig}"
}
