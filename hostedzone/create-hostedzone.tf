variable vpc_id {}
variable zone_name {}


resource "aws_route53_zone" "private" {
  name = "${var.zone_name}"

  vpc {
    vpc_id = "${var.vpc_id}"
  }
}