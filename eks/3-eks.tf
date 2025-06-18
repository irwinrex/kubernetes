# ----------------------------------------------------------------------------
# DATA SOURCE: AWS Caller Identity
# ----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ----------------------------------------------------------------------------
# MODULE: EKS with Cilium Compatibility (Initial Bootstrapping Phase)
# ----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_name    = "${local.env}-eks"
  cluster_version = local.eks_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  bootstrap_self_managed_addons = false

  # Step 1: Enable default CNI & kube-proxy during bootstrap
  cluster_addons = {
    coredns                = {}
    vpc-cni                = {}     # <-- Enabled initially
    kube-proxy             = {}     # <-- Enabled initially
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    "${local.env}-${local.project}" = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3a.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 1

      create_access_entry = true
      access_entry_metadata = {
        kubernetes_groups = ["system:masters"]
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }

      taints = {
        critical = {
          key    = "node.cilium.io/agent-not-ready"
          value  = "true"
          effect = "NO_EXECUTE"
        }
      }

      labels = {
        "karpenter.sh/discovery" = "${local.eks_name}-kpt"
        Environment              = local.env
        NodeType                 = "management"
      }
    }
  }

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    TerraformRunnerAdmin = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = {
        ClusterAdmin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = "${local.env}-kpt"
  }
  cluster_tags = {
    "karpenter.sh/discovery" = "${local.env}-kpt"
  }

  tags = {
    Environment = local.env
    Terraform   = "true"
  }
}

# ----------------------------------------------------------------------------
# MODULE: IAM Role for Cilium IRSA (using EKS Pod Identity)
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "cilium_irsa" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:CreateTags",
      "ec2:DeleteNetworkInterface",
      "ec2:Describe*",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses",
      "tag:GetResources"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cilium_irsa" {
  name   = "${local.env}-cilium-irsa"
  path   = "/"
  policy = data.aws_iam_policy_document.cilium_irsa.json
}

module "cilium_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.34.0"

  role_name_prefix = "${local.env}-cilium"

  role_policy_arns = {
    cilium = aws_iam_policy.cilium_irsa.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cilium"]
    }
  }
}

# ----------------------------------------------------------------------------
# HELM RELEASE: Cilium with ENI IPAM (EKS Pod Identity + IRSA)
# ----------------------------------------------------------------------------
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.17.4"
  namespace  = "kube-system"

  values = [yamlencode({
    tolerations = [
      {
        operator = "Exists"
      }
    ]

    kubeProxyReplacement = true

    ipam = {
      mode = "eni"
    }

    eni = {
      enabled                      = true
      updateEC2AdapterLimitViaAPI = true
      awsReleaseExcessIPs         = false
      awsEnablePrefixDelegation   = true
    }

    serviceAccount = {
      create = true
      name   = "cilium"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.cilium_irsa.iam_role_arn
      }
    }

    podIdentity = {
      enabled = true
    }

    bpf = {
      masquerade  = true
      hostRouting = true
    }

    loadBalancer = {
      algorithm = "maglev"
      mode      = "dsr"
    }

    bandwidthManager = {
      enabled = true
      bbr     = true
    }

    encryption = {
      enabled = false
      type    = "wireguard"
    }
  })]
}

# ----------------------------------------------------------------------------
# NOTE: Once Cilium is deployed and healthy, you can disable aws-node & kube-proxy safely
# - Set vpc-cni = { enabled = false }
# - Set kube-proxy = { enabled = false }
# - OR: kubectl delete ds aws-node/kube-proxy manually before next apply
# ----------------------------------------------------------------------------