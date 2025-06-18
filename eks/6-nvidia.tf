

# # Create NVIDIA device plugin ConfigMap
# resource "kubectl_manifest" "nvidia_device_plugin_config" {
#   yaml_body = <<-YAML
#     apiVersion: v1
#     kind: ConfigMap
#     metadata:
#       name: nvidia-device-plugin-config
#       namespace: gpu
#     data:
#       config.json: |
#         {
#           "version": "v1",
#           "flags": {
#             "migStrategy": "none",
#             "failOnInitError": false,
#             "nvidiaDriverRoot": "/",
#             "deviceDiscoveryStrategy": "auto"
#           },
#           "resources": {
#             "gpus": [
#               {
#                 "pattern": "*",
#                 "name": "nvidia.com/gpu"
#               }
#             ]
#           },
#           "sharing": {
#             "mps": {
#               "enabled": true,
#               "resources": [
#                 {
#                   "name": "nvidia.com/gpu",
#                   "replicas": 4
#                 }
#               ]
#             }
#           }
#         }
#   YAML

#   depends_on = [
#     kubectl_manifest.gpu_namespace
#   ]
# }

# # Create NVIDIA device plugin DaemonSet
# resource "kubectl_manifest" "nvidia_device_plugin_daemonset" {
#   yaml_body = <<-YAML
#     apiVersion: apps/v1
#     kind: DaemonSet
#     metadata:
#       name: nvidia-device-plugin-daemonset
#       namespace: gpu
#     spec:
#       selector:
#         matchLabels:
#           app: nvidia-device-plugin
#       template:
#         metadata:
#           labels:
#             app: nvidia-device-plugin
#         spec:
#           tolerations:
#           - key: nvidia.com/gpu
#             operator: Exists
#             effect: NoSchedule
#           priorityClassName: system-node-critical
#           containers:
#           - image: nvcr.io/nvidia/k8s-device-plugin:v0.17.0
#             name: nvidia-device-plugin-ctr
#             args:
#             - --config=/etc/nvidia-device-plugin/config.json
#             - --mps-enabled
#             securityContext:
#               allowPrivilegeEscalation: false
#               capabilities:
#                 drop: ["ALL"]
#             resources:
#               limits:
#                 nvidia.com/gpu: 1
#             volumeMounts:
#             - name: device-plugin
#               mountPath: /var/lib/kubelet/device-plugins
#             - name: config
#               mountPath: /etc/nvidia-device-plugin
#           volumes:
#           - name: device-plugin
#             hostPath:
#               path: /var/lib/kubelet/device-plugins
#           - name: config
#             configMap:
#               name: nvidia-device-plugin-config
#   YAML

#   depends_on = [
#     kubectl_manifest.nvidia_device_plugin_config,
#     kubectl_manifest.gpu_namespace
#   ]
# }
# # Optional test gpu pod
# resource "kubectl_manifest" "example_gpu_deployment" {
#   yaml_body = <<-YAML
#     apiVersion: apps/v1
#     kind: Deployment
#     metadata:
#       name: gpu-deployment-example
#       namespace: gpu
#     spec:
#       replicas: 1
#       selector:
#         matchLabels:
#           app: gpu-test
#       template:
#         metadata:
#           labels:
#             app: gpu-test
#         spec:
#           containers:
#           - name: gpu-container
#             image: nvidia/cuda:11.6.2-runtime-ubuntu20.04
#             resources:
#               limits:
#                 cpu: "3"
#                 memory: "3Gi"
#             command: ["nvidia-smi"]
#           tolerations:
#           - key: nvidia.com/gpu
#             operator: Exists
#             effect: NoSchedule
#   YAML

#   depends_on = [
#     kubectl_manifest.nvidia_device_plugin_daemonset,
#     kubectl_manifest.gpu_namespace
#   ]
# }

