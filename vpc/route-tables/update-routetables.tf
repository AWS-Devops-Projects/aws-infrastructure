variable region {}
variable vpc_id {}
variable route_table_ids {
  type = "list"
}
variable public_subnet_ids {
  type = "list"
}
variable tags {
  type = "map"
}
variable nat_needed {
  default = false
}
variable environment {}

# Get the region compacted name, with no dashes, e.q. "uswest2"
locals {
  sregion = "${replace(var.region, "-", "")}"
}

## Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = "${var.vpc_id}"

  tags  {
    Name = "igw-${var.environment}-${local.sregion}-${lookup(var.tags,"Name")}"
    Owner = "${lookup(var.tags, "Owner")}"
    Purpose = "${lookup(var.tags, "Purpose")}"
  }
}

## Create EIP for NAT Gateway
resource "aws_eip" "nat" {
  count  = "${var.nat_needed}"
}

## Create NAT Gateway
resource "aws_nat_gateway" "gw" {
    count  = "${var.nat_needed}"
    allocation_id = "${aws_eip.nat.id}"
    subnet_id     = "${var.public_subnet_ids[0]}"
    tags {
      Name = "nat-${var.environment}-${local.sregion}-${lookup(var.tags,"Name")}"
      Owner = "${lookup(var.tags, "Owner")}"
      Purpose = "${lookup(var.tags, "Purpose")}"
    }
}

## Create Default route for Public Subnets
resource "aws_route" "igw" {
  route_table_id            = "${var.route_table_ids[0]}"
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.main.id}"
  depends_on = [ "aws_internet_gateway.main" ]
}

## Create default route for Private subnets
resource "aws_route" "nat" {
  count = "${var.nat_needed}"
  route_table_id            = "${var.route_table_ids[1]}"
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.gw.id}"
  depends_on = [ "aws_nat_gateway.gw" ]
}

output  "aws_nat_gateway_id" {
    value = "${aws_nat_gateway.gw.*.id}"
}

## Create route to Peering VPC 
// resource "aws_route" "private-local" {
//     count = 2
//     route_table_id            = "${aws_route_table.new.*.id[count.index]}"
//     destination_cidr_block    = "${data.aws_vpc.peer.cidr_block}"
//     vpc_peering_connection_id = "${var.peer_connection_id}"
//     depends_on = [ "aws_route_table.new" ]
// }

// ## Create Route Public and Private Route tables 
// resource "aws_route_table" "new" {
//   count = 2 
//   vpc_id = "${var.vpc_id}"
//   tags {
//     Name = "${lookup(var.tags, "Purpose")}-${(count.index == 0 ? "public" : "private")}"
//     Owner = "${lookup(var.tags, "Owner")}"
//     Purpose = "${lookup(var.tags, "Purpose")}"
//   }
// }
## Query peering VPC to add route
// data "aws_vpc" "peer" {
//     id = "${var.peer_vpc_id}"
// }
// ## Query public subnet to create NAT Gateway
// data "aws_subnet_ids" "public" {
//   vpc_id = "${var.vpc_id}"

//   tags {
//     type = "*public*"
//   }
// }
// variable peer_vpc_id {}
// variable peer_connection_id {}
