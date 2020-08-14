## Assume role policy for  EKS Cluster Appmesh
data "aws_iam_policy_document" "eksappmesh_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.ekscluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:appmesh-system:appmesh-controller"]
    }

    principals {
      identifiers = ["${aws_iam_openid_connect_provider.ekscluster.arn}"]
      type        = "Federated"
    }
  }
}

## IAM Role for EKS Cluster autoscaler
resource "aws_iam_role" "eksappmesh" {
  assume_role_policy = data.aws_iam_policy_document.eksappmesh_assume_role_policy.json
  name               = "${var.cluster_name}-appmesh"
}

## Attach policy AWSCloudMapFullAccess 
resource "aws_iam_role_policy_attachment" "eksappmesh_AWSCloudMapFullAccess" {
  role       = aws_iam_role.eksappmesh.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudMapFullAccess"
}

## Attach policy AWSAppMeshFullAccess 
resource "aws_iam_role_policy_attachment" "eksappmesh_AWSAppMeshFullAccess" {
  role       = aws_iam_role.eksappmesh.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshFullAccess"
}
