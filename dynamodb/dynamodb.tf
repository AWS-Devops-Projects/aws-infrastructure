variable dynamodb_table_name {}
variable tags { type = map }

resource "aws_dynamodb_table" "terraform-state" {
  count = "${var.dynamodb_table_name == "" ? 0 : 1 }"
  name           = "${var.dynamodb_table_name}"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
  tags  {
      Name = "${lookup("Name",var.tags)}"
      Owner = "${lookup("Owner",var.tags)}"
  }
}