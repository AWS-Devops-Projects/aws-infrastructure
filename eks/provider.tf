variable workspace_iam_roles {}
variable env {}
provider "aws" {
	region = var.region
  assume_role {
        role_arn = var.workspace_iam_roles[var.env]
  }
}

terraform {
  required_version = "~> 0.12.12"
}