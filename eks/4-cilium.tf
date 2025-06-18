# resource "helm_release" "cilium" {
#   name       = "cilium"
#   repository = "https://helm.cilium.io/"
#   chart      = "cilium"
#   version    = "1.17.4"
#   namespace  = "kube-system"

#   values = [yamlencode({
#     kubeProxyReplacement = true

#     ipam = {
#       mode = "eni"
#     }

#     eni = {
#       enabled                      = true
#       updateEC2AdapterLimitViaAPI = true
#       awsReleaseExcessIPs         = false
#       awsEnablePrefixDelegation   = true
#     }

#     serviceAccount = {
#       create = true
#       name   = "cilium"
#     }

#     podIdentity = {
#       enabled = true
#     }

#     hubble = {
#       enabled = true
#       relay = {
#         enabled     = true
#         rollOutPods = true
#       }
#       ui = {
#         enabled     = true
#         rollOutPods = true
#       }
#       metrics = {
#         enabled = ["dns", "drop", "tcp", "flow", "port-distribution", "icmp", "httpV2"]
#         serviceMonitor = {
#           enabled = false
#         }
#       }
#     }

#     bpf = {
#       masquerade  = true
#       hostRouting = true
#     }

#     loadBalancer = {
#       algorithm = "maglev"
#       mode      = "dsr"
#     }

#     bandwidthManager = {
#       enabled = true
#       bbr     = true
#     }

#     encryption = {
#       enabled = false
#       type    = "wireguard"
#     }
#   })]
# }
