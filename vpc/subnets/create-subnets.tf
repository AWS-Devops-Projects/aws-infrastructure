variable vpc_id {}
variable region {}
variable environment {}
variable subnet_list {
    type = "list"
}
variable availability_zone {
    type = "list"
}
variable tags {
  type = "map"
}

variable noof-subnet-bits { default = 4 }

# Get the region compacted name, with no dashes, e.q. "uswest2"
locals {
  sregion = "${replace(var.region, "-", "")}"
}

## Query VPC to Create Subnets - Yes, we can pass this as variable, instead of query this value. 
## But why pass 2 parameters if you can query :-)  
data "aws_vpc" "selected" {
    id = "${var.vpc_id}"
}

## Create public and private route-tables 
resource "aws_route_table" "crt" {
  count = 2 
  vpc_id = "${var.vpc_id}"
  tags {
    Name = "rt-${var.environment}-${local.sregion}-${(count.index == 0 ? "public" : "private")}"
    type = "${(count.index == 0 ? "public" : "private")}"
    Owner = "${lookup(var.tags, "Owner")}"
    Purpose = "${lookup(var.tags, "Purpose")}"
  }
}

// sn-<account name>-<region>-<profile>-<az>-<name>

resource "aws_subnet" "services-subnets" {
    count = "${(length(var.subnet_list)/2)*(length(var.availability_zone))}"
    vpc_id = "${var.vpc_id}"
    availability_zone = "${var.region}${var.availability_zone[count.index%3]}"
    cidr_block = "${cidrsubnet(data.aws_vpc.selected.cidr_block, var.noof-subnet-bits, count.index)}"
    map_public_ip_on_launch = "${(var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "public" || 
                         var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "dmz") ?
                         true : false}"
    tags {
        Name = "sn-${var.environment}-${local.sregion}-${var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))]}-${var.availability_zone[count.index%3]}-${var.subnet_list[2*(count.index/(length(var.availability_zone)))]}"
        type = "${var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))]}"
        Owner = "${lookup(var.tags, "Owner")}"
        Purpose = "${lookup(var.tags, "Purpose")}"
    }
}

resource "aws_route_table_association" "assign" {
    count = "${(length(var.subnet_list)/2)*(length(var.availability_zone))}"
    subnet_id      = "${element(aws_subnet.services-subnets.*.id,count.index)}"
    route_table_id = "${(var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "public" || 
                         var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "dmz") ? 
                         aws_route_table.crt.0.id : aws_route_table.crt.1.id}"
}

output "public_subnet_ids" {
    value = "${slice(aws_subnet.services-subnets.*.id,0,3)}"
}
output "private_subnet_ids" {
    value = "${slice(aws_subnet.services-subnets.*.id,3,6)}"
}
output "route_table_ids" {
    value = "${aws_route_table.crt.*.id}"
}


// Name = "${lookup(var.tags, "Purpose")}-${(count.index == 0 ? "public" : "private")}"
// route_table_id = "${var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "public" ? 
// var.route_tables[0] : var.route_tables[1]}"
// map_public_ip_on_launch = "${var.subnet_list[1+(2*(count.index/(length(var.availability_zone))))] == "public" ? true : false }"
// Name = "${lookup(var.tags, "Purpose")}-${var.subnet_list[2*(count.index/(length(var.availability_zone)))]}-${var.availability_zone[count.index%3]}"

