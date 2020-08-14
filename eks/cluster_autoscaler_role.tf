#  Policy for  EKS Cluster autoscaler
resource "aws_iam_policy" "ekscluster-autoscaler-policy" {
  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "${var.cluster_name} Cluster Autoscaler Policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

## Assume role policy for  EKS Cluster autoscaler
data "aws_iam_policy_document" "ekscluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.ekscluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = ["${aws_iam_openid_connect_provider.ekscluster.arn}"]
      type        = "Federated"
    }
  }
}

## IAM Role for EKS Cluster autoscaler
resource "aws_iam_role" "ekscluster-autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.ekscluster_autoscaler_assume_role_policy.json
  name               = "${var.cluster_name}-cluster-autoscaler"
}

## Attach policy 
resource "aws_iam_role_policy_attachment" "ekscluster-autoscaler" {
  role       = aws_iam_role.ekscluster-autoscaler.name
  policy_arn = aws_iam_policy.ekscluster-autoscaler-policy.arn
}
