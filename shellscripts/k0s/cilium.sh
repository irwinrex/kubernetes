#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Cilium Installer for k0s Cluster
# -------------------------------

# You can override these if needed
K8S_API_HOST="${K8S_API_HOST:-127.0.0.1}"
IPAM_MODE="${IPAM_MODE:-cluster-pool}"

check_k0s_ready() {
  echo "🔍 Checking if k0s cluster is running..."
  if ! pgrep -f "k0s controller" > /dev/null; then
    echo "⛔ k0s controller is not running. Attempting to start..."
    systemctl start k0scontroller || {
      echo "❌ Failed to start k0scontroller"
      exit 1
    }
    sleep 5
  fi

  echo "⏳ Waiting for Kubernetes node to be Ready..."
  local timeout=300
  local elapsed=0
  while true; do
    local status
    status=$(k0s kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    [[ "$status" == "True" ]] && {
      echo "✅ Kubernetes node is Ready"
      break
    }

    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for Kubernetes node to become Ready"
      k0s kubectl get nodes -o wide || true
      exit 1
    fi

    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

check_cilium() {
  echo "🔍 Checking Cilium status..."
  if k0s kubectl -n kube-system get pods -l k8s-app=cilium 2>/dev/null | grep -q 'Running'; then
    echo "ℹ️ Cilium pods found, checking health..."
    if cilium status --wait 2>/dev/null; then
      echo "✅ Cilium is healthy and running"
      return 0
    else
      echo "⚠️ Cilium pods exist but not healthy"
      return 1
    fi
  else
    echo "ℹ️ No Cilium pods found, will install Cilium"
    return 1
  fi
}

patch_k0s_config() {
  echo "🔧 Patching /etc/k0s/k0s.yaml for Cilium and eBPF..."
  if [[ -f /etc/k0s/k0s.yaml ]]; then
    if command -v yq &>/dev/null; then
      yq eval -i '
        .spec.network.provider = "custom" |
        .spec.network.kubeProxy.disabled = true
      ' /etc/k0s/k0s.yaml
    else
      sed -i 's/provider: .*/provider: custom/' /etc/k0s/k0s.yaml
      sed -i 's/disabled: false/disabled: true/' /etc/k0s/k0s.yaml
    fi
    systemctl restart k0scontroller
    echo "🔄 Restarted k0scontroller to apply network changes"
    check_k0s_ready
  else
    echo "❌ /etc/k0s/k0s.yaml not found"
    exit 1
  fi
}

install_cilium() {
  echo "🚀 Preparing to install Cilium..."

  patch_k0s_config

  echo "📦 Setting up Helm repo..."
  helm repo add cilium https://helm.cilium.io/ > /dev/null || true
  helm repo update > /dev/null

  CHART_VER=$(helm search repo cilium/cilium --versions | awk 'NR==2{print $2}')
  echo "ℹ️ Using Cilium chart version: ${CHART_VER}"

  NATIVE_ROUTING_CIDR="10.0.0.0/16"
  CLUSTER_POOL_CIDR="10.1.0.0/16"
  CLUSTER_POOL_MASK_SIZE="24"

  if helm ls -n kube-system | grep -q '^cilium\s'; then
    echo "🔄 Upgrading existing Cilium installation..."
    ACTION="upgrade"
  else
    echo "🆕 Installing new Cilium CNI..."
    ACTION="install"
  fi

  helm "${ACTION}" cilium cilium/cilium \
    --version "${CHART_VER}" \
    --namespace kube-system \
    --create-namespace \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="${K8S_API_HOST}" \
    --set k8sServicePort=6443 \
    --set operator.replicas=1 \
    --set ipam.mode="${IPAM_MODE}" \
    --set routingMode=native \
    --set ipv4NativeRoutingCIDR="${NATIVE_ROUTING_CIDR}" \
    --set clusterPoolIPv4PodCIDR="${CLUSTER_POOL_CIDR}" \
    --set clusterPoolIPv4MaskSize="${CLUSTER_POOL_MASK_SIZE}" \
    --set bpf.masquerade=true \
    --set hubble.enabled=true \
    --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
    --set hubble.relay.enabled=true \
    --set prometheus.enabled=true \
    --set operator.prometheus.enabled=true \
    --set debug.enabled=true \
    --wait

  echo "⏳ Waiting for Cilium pods to stabilize..."
  k0s kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
  k0s kubectl -n kube-system rollout status deployment/cilium-operator --timeout=300s

  echo "⏳ Giving Cilium some time to fully settle (60s)..."
  sleep 60

  echo "✅ Cilium CNI installed and ready"
}

test_basic_connectivity() {
  echo "📡 Testing pod-to-pod connectivity..."

  k0s kubectl run bb1 --image=busybox --restart=Never -- sleep 6000 || true
  k0s kubectl run bb2 --image=busybox --restart=Never -- sleep 6000 || true

  echo "⏳ Waiting for BusyBox pods to be ready..."
  local timeout=180
  local elapsed=0
  while true; do
    local statuses
    statuses=$(k0s kubectl get pods bb1 bb2 -o jsonpath='{.items[*].status.containerStatuses[0].ready}')
    [[ "$statuses" == "true true" ]] && break

    if [[ $elapsed -ge $timeout ]]; then
      echo "⚠️ Timeout waiting for BusyBox pods"
      k0s kubectl get pods
      return 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""

  local BB2_IP
  BB2_IP=$(k0s kubectl get pod bb2 -o jsonpath='{.status.podIP}')
  echo "📶 Testing ping from bb1 ➡️ bb2 (${BB2_IP})..."
  if k0s kubectl exec bb1 -- ping -c 4 "$BB2_IP"; then
    echo "✅ Pod-to-pod connectivity test passed"
  else
    echo "⚠️ Pod-to-pod connectivity test failed"
  fi

  echo "🧹 Cleaning up test pods..."
  k0s kubectl delete pod bb1 bb2 --ignore-not-found
}

deploy_cilium_connectivity_check() {
  echo "🔍 Deploying Cilium connectivity check..."
  k0s kubectl create namespace cilium-test 2>/dev/null || true

  local CILIUM_VERSION
  CILIUM_VERSION=$(cilium version | grep -oP 'cilium-cli: \K[0-9\.]+')
  echo "ℹ️ Using Cilium version ${CILIUM_VERSION}"

  k0s kubectl apply -n cilium-test -f \
    "https://raw.githubusercontent.com/cilium/cilium/v${CILIUM_VERSION}/examples/kubernetes/connectivity-check/connectivity-check.yaml"
}

main() {
  check_k0s_ready
  if ! check_cilium; then
    install_cilium
  fi
  test_basic_connectivity
  deploy_cilium_connectivity_check
}

main "$@"
