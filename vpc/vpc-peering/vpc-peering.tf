variable cidr_block {}
variable peer_vpc_id {}
variable local_vpc_id {}
variable tags { type = "map" }
variable "peer_region" {}
variable "peer_profile" {} 

provider "aws" {
  alias  = "peer"
  region = "${var.peer_region}"
  profile = "${peer_profile}"
  # Accepter's credentials.
}

data "aws_caller_identity" "peer" {
  provider = "aws.peer"
}

# Query peering VPC data to create routes i.e., update route-tables 
data "aws_vpc" "peer" {
    id = "${var.peer_vpc_id}"
}

# Query peering vpc route-tables to add route to new VPC
data "aws_route_tables" "peer" {
  vpc_id = "${var.peer_vpc_id}"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = "${var.local_vpc_id}"
  peer_vpc_id   = "${var.peer_vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.peer.account_id}"
  peer_region   = "${var.peer_region}"
  auto_accept   = false

  tags  {
    Side = "Requester"
    Name  = "${lookup(var.tags, "Name")}-Request"
    Owner = "${lookup(var.tags, "Owner")}"
    Purpose = "${lookup(var.tags, "Purpose")}"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = "aws.peer"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.peer.id}"
  auto_accept               = true

  tags  {
    Side = "Accepter"
    Name  = "${lookup(var.tags, "Name")}-Accepter"
    Owner = "${lookup(var.tags, "Owner")}"
    Purpose = "${lookup(var.tags, "Purpose")}"
  }
}

## Add route to Peer VPC route-table
resource "aws_route" "peer" {
    count = "${length(data.aws_route_tables.peer.ids)}"
    route_table_id            = "${data.aws_route_tables.peer.ids[count.index]}"
    destination_cidr_block    = "${var.cidr_block}"
    vpc_peering_connection_id = "${aws_vpc_peering_connection.peer.id}"
}

output "peer_id" {
  value = "${aws_vpc_peering_connection.peer.id}"
}
