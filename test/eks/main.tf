variable "workspace_iam_roles" {
  type = map(string)
  default = {
    dev = "arn:aws:iam::1234567890:role/admin-role"
  }
}


provider "aws" {
  region = "us-west-2"
  assume_role {
    role_arn = var.workspace_iam_roles[terraform.workspace]
  }
}

terraform {
  required_version = "~> 0.12.12"

  backend "s3" {
    bucket = "s3bucket"   # Change bucket name for your account

    # be careful here
    # this key needs to be unique for each of our accounts
    key            = "test_modules/eks_cluster/terraform05282020.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "dynamodb-state-lock"
  }
}