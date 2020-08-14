## Attach policy AmazonEKS_CNI_Policy 
resource "aws_iam_role_policy_attachment" "eksnode_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eksnode.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

## Attach policy AmazonEKSWorkerNodePolicy 
resource "aws_iam_role_policy_attachment" "eksnode_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eksnode.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

## Attach policy AmazonEC2ContainerRegistryReadOnly 
resource "aws_iam_role_policy_attachment" "eksnode_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eksnode.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

## Create eksnode role
resource "aws_iam_role" "eksnode" {
  name = "${var.cluster_name}-eksnode"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}