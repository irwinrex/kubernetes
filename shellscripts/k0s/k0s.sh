#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------------
# Fetch latest stable versions dynamically
# ----------------------------------------------------------------------------

get_latest_kube_version() {
  curl -sSL "https://dl.k8s.io/release/stable.txt"
}

get_latest_k0s_version() {
  # Get latest stable k0s release tag (skip pre-releases)
  curl -sSL "https://api.github.com/repos/k0sproject/k0s/releases/latest" | jq -r '.tag_name'
}

get_latest_cilium_cli_version() {
  curl -sSL "https://api.github.com/repos/cilium/cilium-cli/releases/latest" | jq -r '.tag_name'
}

get_latest_yq_version() {
  curl -sSL "https://api.github.com/repos/mikefarah/yq/releases/latest" | jq -r '.tag_name'
}

# ----------------------------------------------------------------------------
# Variables for tools & versions (initialized dynamically)
# ----------------------------------------------------------------------------

KUBE_VERSION="$(get_latest_kube_version)"
K0S_VERSION="$(get_latest_k0s_version)"
CILIUM_CLI_VERSION="$(get_latest_cilium_cli_version)"
YQ_VERSION="$(get_latest_yq_version)"
TOOLS=(kubectl helm cilium yq k0s jq)

# ----------------------------------------------------------------------------
# Ensure running as root
# ----------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "⛔ Please run this script as root"
  exit 1
fi

# ----------------------------------------------------------------------------
# Function: Check system prerequisites
# ----------------------------------------------------------------------------

check_prerequisites() {
  echo "🔍 Checking system prerequisites..."

  TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
  if [[ $TOTAL_MEM -lt 2048 ]]; then
    echo "⚠️ Warning: Less than 2GB of memory available (${TOTAL_MEM}MB)"
    echo "Press Enter to continue anyway or Ctrl+C to abort"
    read -r
  fi

  CPU_CORES=$(nproc)
  if [[ $CPU_CORES -lt 2 ]]; then
    echo "⚠️ Warning: Less than 2 CPU cores available (${CPU_CORES})"
    echo "Press Enter to continue anyway or Ctrl+C to abort"
    read -r
  fi

  if ! grep -q "^DefaultLimitMEMLOCK=infinity" /etc/systemd/system.conf; then
    echo "🔧 Setting memlock limits for eBPF programs..."
    # Add memlock limits only if missing
    if ! grep -q "memlock" /etc/security/limits.conf; then
      cat >> /etc/security/limits.conf << EOF
* soft memlock unlimited
* hard memlock unlimited
EOF
    fi

    echo "DefaultLimitMEMLOCK=infinity" >> /etc/systemd/system.conf
    systemctl daemon-reexec
    echo "⚠️ System limits updated. A reboot is recommended before continuing."
    echo "Press Enter to continue without rebooting or Ctrl+C to abort"
    read -r
  fi

  if ! lsmod | grep -q '^overlay'; then
    echo "🔧 Loading overlay kernel module for containerd..."
    modprobe overlay || {
      echo "⛔ Failed to load overlay kernel module. Containers will not work."
      exit 1
    }
  fi

  if [[ ! -d /var/lib/containerd ]]; then
    echo "🔧 Creating /var/lib/containerd directory for k0s embedded containerd..."
    mkdir -p /var/lib/containerd
    chown root:root /var/lib/containerd
    chmod 755 /var/lib/containerd
  fi

  if ! systemctl is-active --quiet containerd && ! systemctl is-active --quiet docker; then
    echo "ℹ️ Neither containerd nor docker service detected as running"
    echo "ℹ️ k0s will manage its own container runtime"
  fi

  echo "✅ Prerequisite checks completed"
}

# ----------------------------------------------------------------------------
# Function: Install missing dependencies (kubectl, helm, cilium, yq, k0s, jq)
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
        ;;
      helm)
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod +x get_helm.sh && ./get_helm.sh && rm -f get_helm.sh
        ;;
      cilium)
        OS=$(uname | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)
        case "$ARCH" in
          x86_64) ARCH=amd64 ;;
          aarch64|arm64) ARCH=arm64 ;;
          *) echo "⛔ Unsupported architecture: $ARCH" >&2; exit 1 ;;
        esac
        curl -L --fail --remote-name-all \
          "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${OS}-${ARCH}.tar.gz"{,.sha256sum}
        sha256sum --check "cilium-${OS}-${ARCH}.tar.gz.sha256sum"
        tar -C /usr/local/bin -xzvf "cilium-${OS}-${ARCH}.tar.gz"
        rm -f "cilium-${OS}-${ARCH}.tar.gz"{,.sha256sum}
        ;;
      yq)
        curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
        chmod +x /usr/local/bin/yq
        ;;
      k0s)
        curl -sSLf https://get.k0s.sh | K0S_VERSION="${K0S_VERSION}" sh
        ;;
      jq)
        # Try to install jq via package manager or fallback to binary
        if command -v apt-get &>/dev/null; then
          apt-get update && apt-get install -y jq
        elif command -v yum &>/dev/null; then
          yum install -y jq
        else
          echo "⛔ Please install jq manually, package manager not detected"
          exit 1
        fi
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

  if ! k0s config create > k0s.yaml; then
    echo "⛔ Failed to create k0s config"
    exit 1
  fi

  if [[ -f /etc/systemd/system/k0scontroller.service ]]; then
    echo "ℹ️ k0s controller service already installed, skipping install step"
  else
    echo "🚀 Installing k0s controller service..."
    mkdir -p /etc/k0s
    cp k0s.yaml /etc/k0s/k0s.yaml
    k0s install controller --single -c /etc/k0s/k0s.yaml
  fi

  echo "🔄 Starting k0s controller..."
  systemctl daemon-reload
  systemctl restart k0scontroller || (echo "⛔ Failed to start k0s controller" && exit 1)

  echo "⏳ Waiting for k0s to start (this may take several minutes)..."
  timeout=300
  elapsed=0
  until systemctl is-active --quiet k0scontroller; do
    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for k0s controller to start"
      exit 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""
  echo "✅ k0s controller is running"

  echo "⏳ Waiting for admin.conf to be generated..."
  timeout=300
  elapsed=0
  until [[ -f /var/lib/k0s/pki/admin.conf ]]; do
    if [[ $elapsed -ge $timeout ]]; then
      echo "⛔ Timeout waiting for admin.conf"
      exit 1
    fi
    echo -n "."
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo ""

  echo "🔧 Setting up kubeconfig..."
  mkdir -p ~/.kube
  cp /var/lib/k0s/pki/admin.conf ~/.kube/config
  chown "$(id -u):$(id -g)" ~/.kube/config
  chmod 600 ~/.kube/config
  export KUBECONFIG=~/.kube/config

  if [[ $SUDO_USER ]]; then
    mkdir -p /home/$SUDO_USER/.kube
    cp /var/lib/k0s/pki/admin.conf /home/$SUDO_USER/.kube/config
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube
    chmod 600 /home/$SUDO_USER/.kube/config
  fi

  echo "🔍 Verifying cluster nodes..."
  kubectl get nodes || echo "⚠️ Unable to get nodes - check k0s logs"
}

# ----------------------------------------------------------------------------
# Main execution flow
# ----------------------------------------------------------------------------

main() {
  check_prerequisites
  dependency_check
  install_k0s
}

main "$@"
