# IAM User for EKS Developer
resource "aws_iam_user" "developer_eks_user" {
  name = "developer-eks-user-${local.region}"
}

# IAM Group for EKS Developers
resource "aws_iam_group" "developer_eks_group" {
  name = "developer-eks-group-${local.region}"
}

# IAM Policy for EKS Developer Permissions
resource "aws_iam_policy" "developer_eks" {
  name = "AmazonEKSDeveloperPolicy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# Attach IAM Policy to Group
resource "aws_iam_group_policy_attachment" "developer_eks" {
  group      = aws_iam_group.developer_eks_group.name
  policy_arn = aws_iam_policy.developer_eks.arn
}

# Add User to IAM Group
# resource "aws_iam_user_group_membership" "developer_eks" {
#   user   = aws_iam_user.developer_eks_user.name
#   groups = [aws_iam_group.developer_eks_group.name]
# }

# resource "aws_eks_access_entry" "developer" {
#   cluster_name = module.eks.cluster_name
#   principal_arn = aws_iam_user.developer_eks_user.arn
#   kubernetes_groups = ["viewer"]
# }

# # EKS Viewer Access Entry for IAM Group [ RBAC ]
# resource "kubernetes_cluster_role_binding" "viewer" {
#   metadata {
#     name = "viewer"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "viewer"
#   }

#   subject {
#     kind      = "Group"
#     name      = "viewer"
#     api_group = "rbac.authorization.k8s.io"
#   }

#   depends_on = [ module.eks]
# }