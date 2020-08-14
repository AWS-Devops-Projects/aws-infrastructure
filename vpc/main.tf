# Get the region compacted name, with no dashes, e.q. "uswest2"
locals {
  sregion = "${replace(var.region, "-", "")}"
}

resource "aws_vpc" "customvpc" {
	cidr_block = "${var.cidr_block}"
	enable_dns_support = true
	enable_dns_hostnames = true
	tags {
		Name = "vpc-${var.environment}-${local.sregion}-${lookup(var.tags,"Name")}"
		Purpose = "${lookup(var.tags,"Purpose")}"
		Owner = "${lookup(var.tags,"Owner")}"
		terraform = true
	}
}

## Create subnets with given list from ${var.subnet_list}
module "create-subnets" {
	tags = "${var.tags}"
	subnet_list = "${var.subnet_list}"
	availability_zone = "${var.availability_zone}"
	region = "${var.region}"
	environment = "${var.environment}"
	vpc_id = "${aws_vpc.customvpc.id}"
	source = "subnets"
}

## Create public and private route-tables  
## Create IGW, NAT Gateway and update both public and private route-tables
## Add route to both route-tables to enable routing to peering VPC 
module "update-routetables" {
	tags = "${var.tags}"
	vpc_id = "${aws_vpc.customvpc.id}"
	environment = "${var.environment}"
	region = "${var.region}"
	route_table_ids = "${module.create-subnets.route_table_ids}"
	public_subnet_ids = "${module.create-subnets.public_subnet_ids}"
	nat_needed = true
	source = "route-tables"
}

output "vpc_id" {
	value = "${aws_vpc.customvpc.id}"
}

output "vpc_cidr_block" {
	value = "${var.cidr_block}"
}
output "public_subnet_ids" {
	value = "${module.create-subnets.public_subnet_ids}"
}

output "private_subnet_ids" {
	value = "${module.create-subnets.private_subnet_ids}"
}

output "region" {
	value = "${var.region}"
}
output "availability_zones" {
	value = "${var.availability_zone}"
} 
output "aws_nat_gateway_id" {
	value = "${module.update-routetables.aws_nat_gateway_id}"
}

// peer_vpc_id = "${var.peer_vpc_id}"
// peer_connection_id = "${module.vpc-peering.peer_id}"
