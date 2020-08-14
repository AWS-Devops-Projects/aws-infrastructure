variable vpc_id {}
variable peer_vpc_id {}
variable peer_connection_id {}
variable tags {
  type = "map"
}
variable nat_needed {
  default = false
}

## Query peering VPC to add route
data "aws_vpc" "peer" {
    id = "${var.peer_vpc_id}"
}

## Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = "${var.vpc_id}"

  tags = {
    Name = "services"
  }
}

## Query public subnet to create NAT Gateway
data "aws_subnet_ids" "public" {
  vpc_id = "${var.vpc_id}"

  tags = {
    type = "*public*"
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
    subnet_id     = "${data.aws_subnet_ids.public.ids[0]}"
    tags = "${var.tags}"
}

## Create Route Public and Private Route tables 
resource "aws_route_table" "new" {
  count = 2 
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "${lookup(var.tags, "Purpose")}-${(count.index == 0 ? "public" : "private")}"
    Owner = "${lookup(var.tags, "Owner")}"
    Purpose = "${lookup(var.tags, "Purpose")}"
  }
}
## Create Default route for Public Subnets
resource "aws_route" "igw" {
  route_table_id            = "${aws_route_table.new.*.id[0]}"
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.main.id}"
  depends_on = [ "aws_route_table.new", "aws_internet_gateway.main" ]
}

## Create Default route for Private subnets 
resource "aws_route" "nat" {
  count = "${var.nat_needed}"
  route_table_id            = "${aws_route_table.new.*.id[1]}"
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.gw.id}"
  depends_on = [ "aws_route_table.new", "aws_nat_gateway.gw" ]
}

## Create route to Peering VPC 
resource "aws_route" "private-local" {
    count = 2
    route_table_id            = "${aws_route_table.new.*.id[count.index]}"
    destination_cidr_block    = "${data.aws_vpc.peer.cidr_block}"
    vpc_peering_connection_id = "${var.peer_connection_id}"
    depends_on = [ "aws_route_table.new" ]
}

output "route_table_ids" {
    value = "${aws_route_table.new.*.id}"
}