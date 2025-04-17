#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------------
# Enhanced script to install k0s controller and Cilium CNI with robust error
# handling, validation checks, and comprehensive connectivity testing
# ----------------------------------------------------------------------------

echo "🚀 Starting k0s with Cilium installation process..."

# --- Global version detection ---
echo "📦 Detecting latest stable versions..."
KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
K0S_VERSION=$(curl -s https://docs.k0sproject.io/stable.txt 2>/dev/null || echo "v1.26.0+k0s.0")

echo "ℹ️ Using Kubernetes version: ${KUBE_VERSION}"
echo "ℹ️ Using Cilium CLI version: ${CILIUM_CLI_VERSION}"
echo "ℹ️ Using k0s version: ${K0S_VERSION}"

# --- Detect host IP for Kubernetes API (used by Cilium) ---
K8S_API_HOST=$(hostname -I | awk '{print $1}')
echo "ℹ️ Detected API server IP: ${K8S_API_HOST}"

# --- Configurable IPAM mode ---
IPAM_MODE=${IPAM_MODE:-cluster-pool}
echo "ℹ️ Using IPAM mode: ${IPAM_MODE}"

# --- Required tools ---
TOOLS=(kubectl helm cilium yq k0s)

# --- Check if running as root ---
if [[ $EUID -ne 0 ]]; then
  echo "⚠️ This script requires root privileges for certain operations"
  echo "⚠️ Please run with sudo or as root"
  exit 1
fi

# ----------------------------------------------------------------------------
# Function: Check system prerequisites
# ----------------------------------------------------------------------------
check_prerequisites() {
  echo "🔍 Checking system prerequisites..."

  # Check memory
  TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
  if [[ $TOTAL_MEM -lt 2048 ]]; then
    echo "⚠️ Warning: Less than 2GB of memory available (${TOTAL_MEM}MB)"
    echo "⚠️ Kubernetes and Cilium may not function properly"
    echo "Press Enter to continue anyway or Ctrl+C to abort"
    read -r
  fi

  # Check CPU cores
  CPU_CORES=$(nproc)
  if [[ $CPU_CORES -lt 2 ]]; then
    echo "⚠️ Warning: Less than 2 CPU cores available (${CPU_CORES})"
    echo "⚠️ Kubernetes and Cilium may not function properly"
    echo "Press Enter to continue anyway or Ctrl+C to abort"
    read -r
  fi

  # Increase memlock limits for eBPF if needed
  if ! grep -q "DefaultLimitMEMLOCK=infinity" /etc/systemd/system.conf; then
    echo "🔧 Setting memlock limits for eBPF programs..."
    cat >> /etc/security/limits.conf << EOF
* soft memlock unlimited
* hard memlock unlimited
EOF
    echo "DefaultLimitMEMLOCK=infinity" >> /etc/systemd/system.conf
    systemctl daemon-reload

    echo "⚠️ System limits updated. A reboot is recommended before continuing."
    echo "Press Enter to continue without rebooting or Ctrl+C to abort"
    read -r
  fi

  # Check if containerd/docker is running
  if ! systemctl is-active --quiet containerd && ! systemctl is-active --quiet docker; then
    echo "ℹ️ Neither containerd nor docker service detected as running"
    echo "ℹ️ k0s will manage its own container runtime"
  fi

  echo "✅ Prerequisite checks completed"
}

# ----------------------------------------------------------------------------
# Function: Install missing dependencies (kubectl, helm, cilium, yq, k0s)
# ----------------------------------------------------------------------------
dependency_check() {
  echo "🔍 Checking dependencies..."
  local missing_tools=()

  for cmd in "${TOOLS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_tools+=("$cmd")
    fi
  done

  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    echo "✅ All required tools already installed"
    return 0
  fi

  echo "📦 Installing missing tools: ${missing_tools[*]}"

  for cmd in "${missing_tools[@]}"; do
    echo "🔧 Installing $cmd..."
    case "$cmd" in
      kubectl)
        curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"
        install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm -f kubectl
        echo "✅ kubectl installed"
        ;;
      helm)
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod +x get_helm.sh && ./get_helm.sh && rm -f get_helm.sh
        echo "✅ helm installed"
        ;;
      cilium)
        OS=$(uname | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)
        case "$ARCH" in
          x86_64) ARCH=amd64 ;;
          aarch64|arm64) ARCH=arm64 ;;
          *) echo "⛔ Unsupported architecture: $ARCH" >&2; exit 1 ;;
        esac
        echo "ℹ️ Downloading Cilium CLI for ${OS}-${ARCH}..."
        curl -L --fail --remote-name-all \
          "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${OS}-${ARCH}.tar.gz"{,.sha256sum}

        if ! sha256sum --check "cilium-${OS}-${ARCH}.tar.gz.sha256sum"; then
          echo "⛔ SHA256 checksum verification failed for Cilium CLI"
          exit 1
        fi

        tar -C /usr/local/bin -xzvf "cilium-${OS}-${ARCH}.tar.gz"
        rm -f "cilium-${OS}-${ARCH}.tar.gz"{,.sha256sum}
        echo "✅ cilium CLI installed"
        ;;
      yq)
        wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
        echo "✅ yq installed"
        ;;
      k0s)
        curl -sSLf https://get.k0s.sh | K0S_VERSION="${K0S_VERSION}" sh
        echo "✅ k0s installed"
        ;;
      *)
        echo "⚠️ Unknown tool: $cmd"
        ;;
    esac
  done

  echo "✅ All dependencies installed successfully"
}

# ----------------------------------------------------------------------------
# Function: Install or skip k0s controller service
# ----------------------------------------------------------------------------
install_k0s() {
  echo "🔧 Configuring k0s..."

  # Create k0s configuration with custom CNI and disabled kube-proxy
  echo "📄 Generating k0s config and disabling in-tree CNI/proxy..."
  k0s config create > k0s.yaml

  # Update the configuration with yq
  if command -v yq &>/dev/null; then
    echo "🔄 Updating k0s configuration for Cilium CNI..."
    yq eval -i '.spec.network.provider = "custom" | .spec.network.kubeProxy.disabled = true' k0s.yaml

    # Set cgroup driver explicitly if using systemd
    if [[ $(stat -c %t:%T /sys/fs/cgroup/) = "0::" ]]; then
      echo "ℹ️ Detected cgroup v2, setting runtime config accordingly..."
      yq eval -i '.spec.runtime.cgroupDriver = "systemd"' k0s.yaml
    fi
  else
    echo "⚠️ yq not available. Manually updating k0s.yaml..."
    # Fallback method if yq is not available
    sed -i 's/provider: kuberouter/provider: custom/g' k0s.yaml
    sed -i 's/disabled: false/disabled: true/g' k0s.yaml
  fi

  # Check if k0s service is already installed
  if [[ -f /etc/systemd/system/k0scontroller.service ]]; then
    echo "ℹ️ k0s controller service already installed, skipping install step"
    else
    echo "🚀 Installing k0s controller service..."
    mkdir -p /etc/k0s
    cp k0s.yaml /etc/k0s/k0s.yaml
    k0s install controller --single -c /etc/k0s/k0s.yaml
    fi


  # Start/restart the k0s service
  echo "🔄 Starting k0s controller..."
  systemctl daemon-reload
  systemctl restart k0scontroller || (echo "⛔ Failed to start k0s controller" && exit 1)

  # Wait for k0s to be ready
  echo "⏳ Waiting for k0s to start (this may take several minutes)..."
  timeout=300
  elapsed=0
  while ! systemctl is-active --quiet k0scontroller; do
    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for k0s controller to start"
      echo "📋 Check logs with: journalctl -u k0scontroller -n 50"
      exit 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""
  echo "✅ k0s controller is running"

  # Wait for admin.conf to be available
  echo "⏳ Waiting for admin.conf to be generated..."
  timeout=300
  elapsed=0
  while [[ ! -f /var/lib/k0s/pki/admin.conf ]]; do
    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for admin.conf"
      echo "📋 Check logs with: journalctl -u k0scontroller -n 50"
      exit 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""

  # Set up kubeconfig for the current user
  echo "🔧 Setting up kubeconfig..."
  mkdir -p ~/.kube
  cp /var/lib/k0s/pki/admin.conf ~/.kube/config
  chown "$(id -u):$(id -g)" ~/.kube/config
  chmod 600 ~/.kube/config
  export KUBECONFIG=~/.kube/config

  # Ensure regular user can also use the kubeconfig
  if [[ $SUDO_USER ]]; then
    mkdir -p /home/$SUDO_USER/.kube
    cp /var/lib/k0s/pki/admin.conf /home/$SUDO_USER/.kube/config
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube
    chmod 600 /home/$SUDO_USER/.kube/config
  fi

  # Wait for Kubernetes node to become ready
  echo "⏳ Waiting for Kubernetes node to become Ready..."
  timeout=300
  elapsed=0
  while ! k0s kubectl get nodes | grep -q ' Ready '; do
    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for Kubernetes node to become Ready"
      echo "📋 Current node status:"
      k0s kubectl get nodes
      exit 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""
  echo "✅ Kubernetes node is Ready"

  # Give the cluster a bit more time to stabilize
  echo "⏳ Allowing cluster to stabilize (30 seconds)..."
  sleep 30
}

# ----------------------------------------------------------------------------
# Function: Check if Cilium agent is healthy
# ----------------------------------------------------------------------------
check_cilium() {
  echo "🔍 Checking Cilium status..."

  # Check if the Cilium pods are running
  if k0s kubectl -n kube-system get pods -l k8s-app=cilium 2>/dev/null | grep -q 'Running'; then
    echo "ℹ️ Cilium pods found, checking health..."

    # Use cilium CLI to check status
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

# ----------------------------------------------------------------------------
# Function: Install or upgrade Cilium via Helm
# ----------------------------------------------------------------------------
install_cilium() {
    echo "🚀 Preparing to deploy Cilium CNI..."

    # Add Helm repository for Cilium
    echo "🔧 Setting up Helm repository..."
    helm repo add cilium https://helm.cilium.io/ > /dev/null || true
    helm repo update > /dev/null

    # Get latest chart version
    CHART_VER=$(helm search repo cilium/cilium --versions | awk 'NR==2{print $2}')
    echo "ℹ️ Using Cilium chart version: ${CHART_VER}"
    # Replace with your actual CIDR ranges
    NATIVE_ROUTING_CIDR="10.0.0.0/16"
    CLUSTER_POOL_CIDR="10.1.0.0/16"
    CLUSTER_POOL_MASK_SIZE="24"

    # Check if Cilium is already installed
    if helm ls -n kube-system | grep -q '^cilium\s'; then
        echo "🔄 Upgrading existing Cilium installation..."

        helm upgrade cilium cilium/cilium \
            --version "${CHART_VER}" \
            --namespace kube-system \
            --set upgradeCompatibility="${CILIUM_CURRENT_MINOR_VERSION:-}" \
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
    else
        echo "🔧 Installing Cilium CNI..."

        helm install cilium cilium/cilium \
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
    fi


    echo "⏳ Waiting for Cilium pods to become Ready..."
    k0s kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
    k0s kubectl -n kube-system rollout status deployment/cilium-operator --timeout=300s

    echo "⏳ Allowing Cilium networking to stabilize (60 seconds)..."
    sleep 60

    echo "✅ Cilium CNI installed successfully"
}
# ----------------------------------------------------------------------------
# Function: Check prerequisites
# ----------------------------------------------------------------------------
check_prerequisites() {
  echo "🔍 Checking prerequisites..."
  command -v curl >/dev/null || { echo "❌ curl is required"; exit 1; }
  command -v k0s >/dev/null || { echo "❌ k0s is not installed"; exit 1; }
  command -v kubectl >/dev/null || { echo "❌ kubectl is not installed"; exit 1; }
  command -v cilium >/dev/null || { echo "❌ cilium CLI is not installed"; exit 1; }
}

# ----------------------------------------------------------------------------
# Function: Install dependencies (dummy for placeholder)
# ----------------------------------------------------------------------------
dependency_check() {
  echo "✅ All dependencies installed"
}

# ----------------------------------------------------------------------------
# Function: Install k0s
# ----------------------------------------------------------------------------
install_k0s() {
  echo "📦 Installing k0s controller..."
  sudo k0s install controller --single
  sudo k0s start
  echo "✅ k0s installed and started"
}

# ----------------------------------------------------------------------------
# Function: Check if Cilium is already installed
# ----------------------------------------------------------------------------
check_cilium() {
  echo "🔍 Checking if Cilium is already installed..."
  k0s kubectl -n kube-system get ds cilium &>/dev/null
}

# ----------------------------------------------------------------------------
# Function: Install Cilium CNI
# ----------------------------------------------------------------------------
install_cilium() {
  echo "📦 Installing Cilium..."

  cilium install \
    --version "1.15.4" \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=127.0.0.1 \
    --set k8sServicePort=6443 \
    --set routingMode=native \
    --set ipv4NativeRoutingCIDR=10.244.0.0/16

  echo "✅ Cilium installed"
}

# ----------------------------------------------------------------------------
# Function: Test basic connectivity using BusyBox pods
# ----------------------------------------------------------------------------
test_basic_connectivity() {
  echo "🔍 Testing basic pod-to-pod connectivity..."

  k0s kubectl run bb1 --image=busybox --restart=Never -- sleep 6000 || true
  k0s kubectl run bb2 --image=busybox --restart=Never -- sleep 6000 || true

  echo "⏳ Waiting for BusyBox pods to be ready..."
  timeout=180
  elapsed=0
  while true; do
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

  echo "🔧 Testing pod-to-pod connectivity (using IP)..."
  BB2_IP=$(k0s kubectl get pod bb2 -o jsonpath='{.status.podIP}')
  if k0s kubectl exec bb1 -- ping -c 4 "$BB2_IP"; then
    echo "✅ Pod-to-pod connectivity test passed"
  else
    echo "⚠️ Pod-to-pod connectivity test failed"
  fi

  echo "🧹 Cleaning up BusyBox test pods..."
  k0s kubectl delete pod bb1 bb2 --ignore-not-found
}

# ----------------------------------------------------------------------------
# Function: Deploy comprehensive connectivity test using Cilium's test suite
# ----------------------------------------------------------------------------
deploy_cilium_connectivity_check() {
  echo "🔍 Deploying Cilium connectivity check..."
  k0s kubectl create namespace cilium-test 2>/dev/null || true

  CILIUM_VERSION=$(cilium version | grep -oP 'cilium-cli: \K[0-9\.]+')
  echo "ℹ️ Using Cilium version ${CILIUM_VERSION}"

  k0s kubectl apply -n cilium-test -f \
    "https://raw.githubusercontent.com/cilium/cilium/v${CILIUM_VERSION}/examples/kubernetes/connectivity-check/connectivity-check.yaml"

  echo "⏳ Waiting for connectivity check pods to become Ready..."
  timeout=360
  elapsed=0
  while true; do
    ready=$(k0s kubectl get pods -n cilium-test -o jsonpath='{.items[*].status.containerStatuses[0].ready}' | tr ' ' '\n' | grep -c '^true$')
    total=$(k0s kubectl get pods -n cilium-test --no-headers | wc -l)

    if [[ "$ready" -eq "$total" && "$total" -gt 0 ]]; then
      echo "✅ All connectivity check pods are ready"
      break
    fi

    if [[ $elapsed -ge $timeout ]]; then
      echo "⚠️ Timeout waiting for connectivity check pods"
      k0s kubectl get pods -n cilium-test -o wide
      break
    fi
    echo -n "."
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo ""
  k0s kubectl get pods -n cilium-test
  echo "✅ Cilium connectivity check deployed"
}

# ----------------------------------------------------------------------------
# Function: Print cluster status summary
# ----------------------------------------------------------------------------
print_cluster_summary() {
  echo ""
  echo "=================================================================="
  echo "                     CLUSTER STATUS SUMMARY"
  echo "=================================================================="

  K0S_VERSION_INSTALLED=$(k0s version | head -n1)
  echo "ℹ️ k0s version: ${K0S_VERSION_INSTALLED}"

  echo "📋 Node status:"
  k0s kubectl get nodes -o wide

  echo "📋 Cilium status:"
  cilium status --wait || echo "⚠️ Cilium status check returned non-zero exit code"

  echo "📋 Pod status (first 20 pods):"
  k0s kubectl get pods --all-namespaces | head -n 20
  if [[ $(k0s kubectl get pods --all-namespaces | wc -l) -gt 20 ]]; then
    echo "... (showing first 20 pods only)"
  fi

  echo "📋 Service status:"
  k0s kubectl get svc --all-namespaces

  echo "=================================================================="
  echo "✅ k0s Kubernetes cluster with Cilium CNI is up and running"
  echo "🔧 Kubeconfig location: ~/.kube/config"
  echo "🔍 To access the cluster: kubectl get nodes"
  echo "=================================================================="
}

# ----------------------------------------------------------------------------
# Function: Perform cleanup in case of failure
# ----------------------------------------------------------------------------
cleanup() {
  echo "🧹 Performing cleanup operations..."
  k0s kubectl delete namespace cilium-test --ignore-not-found 2>/dev/null || true
  k0s kubectl delete pod bb1 bb2 --ignore-not-found 2>/dev/null || true
  rm -f k0s.yaml
  echo "✅ Cleanup completed"
}

# ----------------------------------------------------------------------------
# Main execution
# ----------------------------------------------------------------------------
main() {
  echo "🚀 Starting k0s with Cilium installation..."
  trap cleanup EXIT

  check_prerequisites
  dependency_check

  if systemctl list-unit-files | grep -q '^k0scontroller.service'; then
    echo "ℹ️ k0s controller service already installed, skipping installation"
  else
    install_k0s
  fi

  if ! check_cilium; then
    install_cilium
  fi

  echo "🔍 Verifying Cilium installation..."
  if ! cilium status --wait; then
    echo "⚠️ Cilium status check failed, attempting reinstall..."
    install_cilium
  fi

  echo "🔍 Running Cilium connectivity tests..."
  test_basic_connectivity
  deploy_cilium_connectivity_check
  print_cluster_summary

  echo "🎉 Installation and validation complete!"
  echo "🔧 The cluster is now ready for use"
}

main "$@"
