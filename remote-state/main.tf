module "s3" {
    source  = "../s3"
    s3bucket-name = "${var.s3bucket-name}"
    region = "${var.region}"
    tags = "${var.tags}"
}