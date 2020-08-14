# AWS Infrastructure Modules
Terraform modules to build AWS Infrastructure

## Create or Update Module

1. **Clone, Branch, Commit Changes and Submit PR to Review**
    ```
    git clone git@github.com:SamsonGudise/aws-infrastructure.git
    ```
    ```
    $ git checkout -b "CCDV-001"
    Switched to a new branch 'CCDV-001'
    ```
    ```
    git push --set-upstream origin CCDV-001
    ```
2. **Tag Version After Merge**
    ```
    git tag -a "v0.0.2" -m "New features"
    git push --follow-tags 
    ```
3. **Update [repository](https://github.com/SamsonGudise/aws-infrastructure) to consume new version**
    
    Change v0.0.1 -> v0.0.2
    ```
    module  "build-vpc" {
        region = "${var.region}"
        subnet_list = "${var.subnet_list}"
        cidr_block = "${var.cidr_block}"
        peer_vpc_id =  "${var.peer_vpc_id}"
        tags = "${var.tags}"
        # source  = "git::git@github.com:SamsonGudise/infrastructure-modules.git//vpc?ref=v0.0.1"
        source  = "git::git@github.com:SamsonGudise/infrastructure-modules.git//vpc?ref=v0.0.2"
    }
