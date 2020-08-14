# VPC Module

## Required parameters

1. **variable cidr_block{}**

   
   Use `tfvars` file(s) to pass any list of variables such as `cidr_block`, `region` etc., Keep your code dry! Deploy to multiple accounts and regions, just by exporting different environment variables.

1. **variable region{}**

    Use `makefile` and `environment` variables to set `region` and `cidr_block` variables using `tfvars` file. 
    ```
    $ cat Makefile
    init:
        terraform init
    plan:
        terraform init -backend-config=${ENV}-${REGION}-backend.tfvars
        terraform plan -out tfplan.out -var-file=${ENV}-${REGION}.tfvars

    apply:
        terraform apply tfplan.out

    clean:
        rm -rf .terraform
    destroy:
        terraform destroy -var-file=${ENV}-${REGION}.tfvars
    ```
    ```
    $ export REGION=us-west-2
    $ export ENV=test
    ```
    ```
    $ cat test-us-west-2.tfvars
    cidr_block="10.10.0.0/16"
    region="us-west-2"
    ```
1. **variable subnet_list { type = "list" }**

    ```
        variable subnet_list { 
            type = "list"
            default = ["app","private","web","public"]
        }
    ```
    `subnet_list` contains name and type.  Example above creates **app** `private subnets` and **web** `public subnets` in given availbility_zone `us-west-2a` `us-west-2b` and `us-west-2c`


## Optional parameters
1. **availability_zone**
    
    ```
    variable availability_zone {
        type = "list"
        default = ["a","b","c"]
    }
    ```
1. **variable peer_vpc_id {}**
    
    Pass `peer_vpc_id` to create vpc_peering across regions and accounts. 
1. **variable tags { type = "map"}**

    `tags` Optional variable. However, include following 3 map values `Name`, `Owner` and `Purpose` in addition to your own or skip tags.  Module use following default `tags`
    ```
    variable tags {
	    type = "map"
	    default {
		    Name = "test-vpc"
                Owner = "SamsonGudise"
            Purpose = "Test"
	    }
    }
    ```