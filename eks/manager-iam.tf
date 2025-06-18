# Data source to retrieve current AWS account ID
data "aws_caller_identity" "main" {}

# IAM Role to be assumed by the EKS Manager
resource "aws_iam_role" "eks_manager" {
  name = "${local.env}-${local.eks_name}-eks-manager"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.main.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# IAM Policy for EKS Manager Role Permissions
resource "aws_iam_policy" "eks_manager" {
  name = "AmazonEKSManagerPolicy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "eks.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

# Attach the EKS Manager Policy to the Role
resource "aws_iam_role_policy_attachment" "eks_manager_attachment" {
  role       = aws_iam_role.eks_manager.name
  policy_arn = aws_iam_policy.eks_manager.arn
}

# IAM User for EKS Manager
resource "aws_iam_user" "manager" {
  name = "manager-eks-user-${local.region}"
}

# IAM Group for Manager with AssumeRole Permissions
resource "aws_iam_group" "manager_group" {
  name = "manager-eks-group-${local.region}"
}

# IAM Policy to Allow Manager Group to Assume the EKS Manager Role
resource "aws_iam_policy" "eks_assume_manager" {
  name = "AmazonEKSAssumeManagerPolicy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "${aws_iam_role.eks_manager.arn}"
    }
  ]
}
POLICY
}

# # Attach the Assume Role Policy to the Manager Group
# resource "aws_iam_group_policy_attachment" "manager_assume_role" {
#   group      = aws_iam_group.manager_group.name
#   policy_arn = aws_iam_policy.eks_assume_manager.arn
# }

# # Add Manager User to the Manager Group
# resource "aws_iam_user_group_membership" "manager_membership" {
#   user   = aws_iam_user.manager.name
#   groups = [aws_iam_group.manager_group.name]
# }

# # Kubernetes Cluster Role Binding for EKS Manager [ RBAC ]
# resource "kubernetes_cluster_role_binding" "manager" {
#   metadata {
#     name = "manager"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "manager"
#   }

#   subject {
#     kind      = "Group"
#     name      = "manager"
#     api_group = "rbac.authorization.k8s.io"
#   }
#   depends_on = [ module.eks ]
# }