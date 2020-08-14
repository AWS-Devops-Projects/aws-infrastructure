#  Policy for  EKS Cluster external dns
# External DNS Policy
resource "aws_iam_policy" "external_dns_policy" {
  name        = "${var.cluster_name}-external-dns-policy"
  description = "External DNS Policy"

  policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Action": [
       "route53:ChangeResourceRecordSets"
     ],
     "Resource": [
       "arn:aws:route53:::hostedzone/*"
     ]
   },
   {
     "Effect": "Allow",
     "Action": [
       "route53:ListHostedZones",
       "route53:ListResourceRecordSets"
     ],
     "Resource": [
       "*"
     ]
   }
 ]
}
EOF
}

## Assume role policy for  EKS Cluster external dns
data "aws_iam_policy_document" "eksexternal_dns_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.ekscluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    principals {
      identifiers = ["${aws_iam_openid_connect_provider.ekscluster.arn}"]
      type        = "Federated"
    }
  }
}

## IAM Role for EKS Cluster autoscaler
resource "aws_iam_role" "eksexternal_dns" {
  assume_role_policy = data.aws_iam_policy_document.eksexternal_dns_assume_role_policy.json
  name               = "${var.cluster_name}-external-dns"
}

## Attach policy 
resource "aws_iam_role_policy_attachment" "eksexternal_dns" {
  role       = aws_iam_role.eksexternal_dns.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}
