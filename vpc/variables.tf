variable region {}
variable subnet_list { type = "list" }
variable availability_zone {
    type = "list"
    default = ["a","b","c"]
}
variable cidr_block {}

variable tags {
	type = "map"
	default {
		Name = "test-vpc"
		Owner = "SamsonGudise"
		Purpose = "Test"
	}
}
variable peer_vpc_id { default = "" }
variable environment {}