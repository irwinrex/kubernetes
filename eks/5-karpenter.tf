# # This defines the permissions Karpenter needs.
# # resource "aws_iam_policy" "karpenter_controller" {
# #   name   = "${local.env}-KarpenterControllerPolicy"
# #   policy = file("./policies/karpenter-controller.json") # Ensure this file exists and has the official policy
# # }
# # -----------------------------------------------------------------------------
# # Karpenter
# # -----------------------------------------------------------------------------
# module "karpenter" {
#   source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#   version = "~> 20.37.0"

#   cluster_name = module.eks.cluster_name

#   # --- EKS Pod Identity Configuration ---
#   enable_pod_identity             = true
#   create_pod_identity_association = true
#   enable_v1_permissions = true

#   # The Helm chart below creates a service account named "karpenter" in the "karpenter" namespace.
#   service_account = "karpenter"
#   namespace       = "karpenter"

#   # --- Node Role Configuration ---
#   create_node_iam_role = true
#   node_iam_role_name   = "${local.env}-kpt-node"
#   node_iam_role_additional_policies = {
#     AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#     AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#     AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#     # KarpenterControllerPolicy          = aws_iam_policy.karpenter_controller.arn
#   }

#   # Naming Conventions for SQS/EventBridge
#   queue_name       = "${local.env}-kpt"
#   rule_name_prefix = "${local.env}-kpt"

#   tags = {
#     Environment = local.env
#     Terraform   = "true"
#   }

#   depends_on = [module.eks, helm_release.cilium]
# }

# # ECR Public Access
# data "aws_ecrpublic_authorization_token" "token" {}

# resource "helm_release" "karpenter" {
#   name = "karpenter"
#   namespace        = "karpenter"
#   create_namespace = true

#   chart      = "karpenter"
#   repository = "oci://public.ecr.aws/karpenter"
#   version    = local.karpenter_version

#   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password = data.aws_ecrpublic_authorization_token.token.password

#   values = [
#     yamlencode({
#       settings = {
#         clusterName       = module.eks.cluster_name
#         interruptionQueue = module.karpenter.queue_name
#       }

#       # This serviceAccount block is now clean and correct for EKS Pod Identity.
#       serviceAccount = {
#         name      = "karpenter"
#         namespace = "karpenter"
#         annotations = {}        # Annotations are NOT needed for Pod Identity
#       }

#       controller = {
#         replicas = 1
#         resources = {
#           requests = { cpu = "1", memory = "1Gi" }
#           limits   = { cpu = "1", memory = "1Gi" }
#         }
#       }
#     })
#   ]

#   depends_on = [
#     module.eks,
#     module.karpenter
#   ]

#   wait = true
# }
# # -----------------------------------------------------------------------------
# # Namespace for GPU Workloads
# # -----------------------------------------------------------------------------
# resource "kubectl_manifest" "gpu_namespace" {
#   yaml_body = <<-YAML
#     apiVersion: v1
#     kind: Namespace
#     metadata:
#       name: gpu
#   YAML
# }
# # -----------------------------------------------------------------------------
# # Default EC2NodeClass and NodePool for General Workloads
# # -----------------------------------------------------------------------------
# resource "kubectl_manifest" "karpenter_node_pool" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1
#     kind: NodePool
#     metadata:
#       name: default
#       namespace: default
#       annotations:
#         argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
#     spec:
#       template:
#         spec:
#           requirements:
#           - key: "karpenter.sh/capacity-type"
#             operator: In
#             values: ["spot"]
#           - key: "karpenter.k8s.aws/instance-family"
#             operator: In
#             values: ["t3a","m6a","c6a"]
#           - key: "karpenter.k8s.aws/instance-generation"
#             operator: Gt
#             values: ["1"]
#           - key: "karpenter.k8s.aws/instance-cpu"
#             operator: In
#             values: ["1","2","4","8","16"]
#           taints:
#           - key: default.com/defalut
#             value: "true"
#             effect: NoSchedule
#           nodeClassRef:
#             group: karpenter.k8s.aws
#             kind: EC2NodeClass
#             name: default
#       limits:
#         cpu: 100
#         memory: 100Gi
#       disruption:
#         consolidationPolicy: WhenEmptyOrUnderutilized
#         consolidateAfter: 20s
#   YAML
#   depends_on = [kubectl_manifest.karpenter_node_class]
# }
# resource "kubectl_manifest" "karpenter_node_class" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1
#     kind: EC2NodeClass
#     metadata:
#       name: default
#       namespace: default
#       annotations:
#         argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
#     spec:
#       amiFamily: Bottlerocket
#       amiSelectorTerms:
#         - alias: bottlerocket@latest
#       role: ${module.karpenter.node_iam_role_name}
#       detailedMonitoring: true
#       blockDeviceMappings:
#       # Root device
#       - deviceName: /dev/xvda
#         ebs:
#           volumeSize: 30Gi
#           volumeType: gp3
#           encrypted: false
#       # Data device: Container resources such as images and logs
#       - deviceName: /dev/xvdb
#         ebs:
#           volumeSize: 50Gi
#           volumeType: gp3
#           encrypted: false
#       subnetSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${local.eks_name}-kpt
#       securityGroupSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${local.eks_name}-kpt
#       tags:
#         Name: default
#         karpenter/NodePool: default
#   YAML

#   depends_on = [helm_release.karpenter]
# }

# # -----------------------------------------------------------------------------
# # GPU EC2NodeClass and NodePool for Specialized Workloads
# # -----------------------------------------------------------------------------
# # resource "kubectl_manifest" "karpenter_node_pool_gpu" {
# #   yaml_body = <<-YAML
# #     apiVersion: karpenter.sh/v1
# #     kind: NodePool
# #     metadata:
# #       name: gpu
# #     spec:
# #       template:
# #         spec:
# #           requirements:
# #           - key: "karpenter.k8s.aws/instance-category"
# #             operator: In
# #             values: ["g", "p"]
# #           - key: "karpenter.sh/capacity-type"
# #             operator: In
# #             values: ["on-demand"]
# #           taints:
# #           - key: nvidia.com/gpu
# #             value: "true"
# #             effect: NoSchedule
# #           nodeClassRef:
# #             group: karpenter.k8s.aws
# #             kind: EC2NodeClass
# #             name: gpu
# #       limits:
# #         "nvidia.com/gpu": 2
# #       disruption:
# #         consolidationPolicy: WhenEmpty
# #         consolidateAfter: 60s
# #   YAML
# #   depends_on = [kubectl_manifest.karpenter_node_class_gpu]
# # }

# # resource "kubectl_manifest" "karpenter_node_class_gpu" {
# #   yaml_body = <<-YAML
# #     apiVersion: karpenter.k8s.aws/v1
# #     kind: EC2NodeClass
# #     metadata:
# #       name: gpu
# #     spec:
# #       amiFamily: Bottlerocket
# #       amiSelectorTerms:
# #         - tags:
# #             karpenter.sh/discovery: ${local.eks_name}-kpt
# #       role: ${module.karpenter.node_iam_role_name}
# #       detailedMonitoring: true
# #       blockDeviceMappings:
# #       - deviceName: /dev/xvda
# #         ebs:
# #           volumeSize: 75Gi
# #           volumeType: gp3
# #           encrypted: true
# #       - deviceName: /dev/xvdb
# #         ebs:
# #           volumeSize: 100Gi
# #           volumeType: gp3
# #           encrypted: true
# #       subnetSelectorTerms:
# #         - tags:
# #             karpenter.sh/discovery: ${local.eks_name}-kpt
# #       securityGroupSelectorTerms:
# #         - tags:
# #             karpenter.sh/discovery: ${local.eks_name}-kpt
# #       tags:
# #         Name: karpenter-gpu
# #         karpenter/NodePool: gpu
# #   YAML
# #   depends_on = [helm_release.karpenter]
# # }
