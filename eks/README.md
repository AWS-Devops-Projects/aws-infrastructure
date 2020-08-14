# EKS Cluster 

### Pre-requisites
*  terraform 0.12 or later
* `openssl`, `sed`, `tac`


### Assumptions
* This module will create `eks cluster` in private subnets. So, VPC must have at least one subnet with `tag:SubnetTier` value `private`


### Required parameters

* `cluster_name` to be created
* `vpc_id` to host eks cluster
* `env`:  aws account or profile 
* `workspace_iam_roles` IAM role to assume

### Optional paramters

* `public_access`  default access to internet is `false`
* `private_access`  default internal access is `true`
* `create_iamrole`  default `false` don't create iamrole and policies
* `region` default `us-west-2`
* `key_name` set valid key_pair to access worker-nodes
* `eks_version` default 1.14
* `admin_access_cidrs` default `[0.0.0.0/0]`
* `rt_tag` default `tag:Name`
* `ssh_sg`  source security_group for ssh access to worker-nodes
* `access_instance_types` list of instances types for access node_group, default `t3.medium`
* `access_labels` map of labels for access_nodegroup. check code for default values.
* `activity_instance_types` list of instances types for activity node_group, default `t3.medium`
* `analytics_instance_types` list of instances types for analytics node_group, default `t3.medium`
* `analytics_min_size` min number of nodes per region for analytics node_group
* `analytics_max_size` max number of nodes per region for analytics node_group
* `analytics_desired_size` desired number of nodes per region for analytics node_group
* `activity_min_size` min number of nodes per region for activity node_group
* `activity_max_size` max number of nodes per region for activity node_group
* `activity_desired_size` desired number of nodes per region for activity node_group
* `activity_custom_min_size` min number of nodes per region for activity custom_node_group, default `0`
* `activity_custom_max_size` max number of nodes per region for activity custom_node_group, default `100`
* `activity_custom_desired_size` desired number of nodes per region for activity custom_node_group, default `0`
* `autoscale_max_size` max number of nodes per region for autoscale nodegroup, default `100`
* `autoscale_min_size` min number of nodes per region for autoscale nodegroup, default `0`
* `autoscale_desired_size` max number of nodes per region for autoscale nodegroup, default `0`
* `nodegroup_config`  define map of nodegroup(s) to be created.  `eks-ng.tf` for default configuration.
* `spot_max_price`  applicable to `activity_custom_nodegroups`
* `max_instance_lifetime` applicable to `activity_custom_nodegroups` disabled by default
* `on_demand_instance_percentage` on_demand instances distribution percent, applicable to custom activity and autoscale nodegroups


### Default Cluster configuration
* prometheus nodegroup with single worker node (m5.large) dedicated for prometheus-server and single point of access for all NodePort services
* 3 nodegroups, one for each availability zone `a`, `b`, `c` with min and desired set to `0` nodes and max set to `100`.
* Initial cluster comes up with one m5.large, will scale based on load.

### Example


        module "create-eks-cluster" {
        source  = "https://github.com/SamsonGudise/aws-infrastructure.git/eks_cluster?ref=v0.0.010"
        # vpc_id = var.vpc_id[terraform.workspace]
        vpc_id = data.terraform_remote_state.network.outputs.vpc_id
        key_name = var.key_pair[terraform.workspace]
        region = "us-west-2"
        cluster_name = var.cluster_name[terraform.workspace]
        env = terraform.workspace
        eks_version = 1.15
        eks_release_version = var.eks_release_version[terraform.workspace]
        workspace_iam_roles = var.workspace_iam_roles
        ssh_sg = data.aws_security_groups.ssh_security_group.ids
        }
* Note:  Check  `../test_modules/eks_cluster` for more details on how to use this module.

### Install-addons 

### Create Route53 `A` record
* Create `A` record for `prometheus` nodegroup node.

        % kubectl get nodes -l app=prometheus        
        NAME                                         STATUS   ROLES    AGE    VERSION
        ip-10-96-86-110.us-west-2.compute.internal   Ready    <none>   5d3h   v1.15.11-eks-af3caf
        %

### Edit Security Group to allow Jenkins slaves and user access
*  EKS Cluster comes up with security group name `eks-cluster-sg-${cluster-name}-[0-9]+` will be assinged to worker nodes.  
*  Change security to allow TCP ports `22`, `443(https)`, `80(http)` and port range `30000-32767` from `172.0\10` and `10.0\9`

### Edit  IAM Role `alb-ingress-controller` Trust Relationships
* Change Trust Reliationships to allow alb-ingress-controller pod to manage ALBs for kube ingress

        {
        "Version": "2012-10-17",
        "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
                "Federated": "arn:aws:iam::122524323692:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/28E5E6E998145B4EA7DCC2DC5DEBB0C9"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
                "StringEquals": {
                "oidc.eks.us-west-2.amazonaws.com/id/28E5E6E998145B4EA7DCC2DC5DEBB0C9:sub": "system:serviceaccount:kube-system:alb-ingress-controller"
                }
        }
        },
        {
        "Effect": "Allow",
        "Principal": {
                "Federated": "arn:aws:iam::122524323692:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/188B8A9BFDCAC6964D3DA55C3D15928B"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
                "StringEquals": {
                "oidc.eks.us-west-2.amazonaws.com/id/188B8A9BFDCAC6964D3DA55C3D15928B:sub": "system:serviceaccount:kube-system:alb-ingress-controller"
                }
        }
        }
        ]
        }

### Role Based Access Controls (RBAC)

#### Cluster access

1. Create kubeconfig -  `aws eks update-kubeconfig --name <clustername> --profile <aws-profile>`


        
        $ aws eks update-kubeconfig --name dev-eks1 --profile=dev     
        Added new context arn:aws:eks:us-west-2:122524323692:cluster/qa-eks1 to /Users/testuser/.kube/config
        
1. Validate your access to cluster
   You might get output like this below.



        $ kubectl get pods 
        error: You must be logged in to the server (Unauthorized)


Get with Cluster Administrator, they need your `RoleARN` and `CanonicalARN` and k8s `namespace` to provide desired access

### Get RoleARN & CanonicalARN
    
        
* token



        % aws eks get-token --cluster-name eks-1-uswest2-dev --region us-west-2 --profile=dev
        {"kind": "ExecCredential", "apiVersion": "client.authentication.k8s.io/v1alpha1", "spec": {}, "status": {"expirationTimestamp": "2020-03-08T09:10:13Z", "token": "<token>"}}

* CanonicalARN



        % aws-iam-authenticator verify -i eks-1-uswest2-dev -t <token>

* RoleARN  : AWS Console

### To be executed by Cluster administrator

*  Required cluster administrator or `system:master` permissions. For this excercise,  I will be providing access to FullAccess to  `demo` namespace  for user's  CanonicalARN:`arn:aws:iam::122524323692:role/AWSReservedSSO_AdministratorAccess_317bbdb6c7f7422b`

1. Update `roles.yaml` for your namespace. You need to create exact copy and update `namespace` and `name` under `metadata` to match naming convention and apply changes.



        kind: Role
        apiVersion: rbac.authorization.k8s.io/v1
        metadata:
        namespace: demo  # must match namespace
        name: demo-role  # name of the role 
        rules:             # Admins permissions
        - apiGroups: [""]
        resources: ["*"]
        verbs: ["*"]
        - apiGroups: ["extensions"]
        resources: ["*"]
        verbs: ["*"]%                                                                                                                    
    

1. Update `rolebindings.yaml` for your namespace. You need to create exact copy and update `metadata:namespace`, `metadata:name`, `Subjects:name` and `roleRef:name` to match naming convention
    

    
        kind: RoleBinding
        apiVersion: rbac.authorization.k8s.io/v1
        metadata:
        name: demo-role-binding # specify the name of the binding. Prepend with CI
        namespace: demo         # specify namespace for binding to exist in.
        subjects:
        - kind: Group             # In this step, we are creating a Group called <namespace-name>-admins. This will be referenced later.
        name: demo-admins
        apiGroup: rbac.authorization.k8s.io
        roleRef:           
        kind: Role
        name: demo-role
        apiGroup: rbac.authorization.k8s.io
   
    

1. Update `aws-auth` configmap  to add `roleARN` and `groups` mapping to complete access request. 



        $ kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth-configmap.yaml

        $ kubectl edit configmap aws-auth -n kube-system

* Insert `rolearn`, `username` and `groups` under `mapRoles: |` 
    

        - rolearn: arn:aws:iam::122524323692:role/AWSReservedSSO_AdministratorAccess_317bbdb6c7f7422b <- CanonicalARN
          username: arn:aws:iam::122524323692:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_317bbdb6c7f7422b <- RoleARN
          groups:
            - demo-role
        
* RoleARN: Role to be assumed to access AWS EKS  

#### Validate access 

Once DevOps Team or CD Job executes above steps. Ready to validate access. 


    $ kubectl get pods -n demo

#### Query worker nodes specific to `node-group`



        kubectl get nodes -l eks.amazonaws.com/nodegroup=access-nodeport
        kubectl get nodes -l eks.amazonaws.com/nodegroup=activity-[0,1,2]
        kubectl get nodes -l eks.amazonaws.com/nodegroup=analytics-[0,1,2]

### Ref: 
* https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html