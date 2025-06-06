#!/usr/bin/env bash
set -euo pipefail

# --- Versions detection ---
echo "📦 Detecting latest stable versions..."
KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
K0S_VERSION=$(curl -s https://docs.k0sproject.io/stable.txt 2>/dev/null || echo "v1.26.0+k0s.0")

TOOLS=(jq)  # First just check/install jq

install_missing_tools() {
  local missing_tools=()
  for tool in "${TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    echo "✅ jq is installed."
    return
  fi

  echo "📦 Installing missing tools: ${missing_tools[*]}"

  for tool in "${missing_tools[@]}"; do
    echo "🔧 Installing $tool..."
    case $tool in
      jq)
        if command -v apt-get &>/dev/null; then
          apt-get update && apt-get install -y jq
        elif command -v pacman &>/dev/null; then
          pacman -Sy --noconfirm jq
        elif command -v yum &>/dev/null; then
          yum install -y jq
        else
          echo "⛔ Cannot detect package manager to install jq. Please install jq manually."
          exit 1
        fi
        ;;
      *)
        echo "⛔ Don't know how to install $tool automatically. Please install manually."
        exit 1
        ;;
    esac
  done
}

# Run jq install first before sourcing helpers
install_missing_tools

# Now source helper scripts which depend on jq
source ./k0s.sh
source ./cilium.sh

# Now extend TOOLS array to all your tools
TOOLS+=(kubectl helm cilium yq k0s)

# Then continue with the rest of your script (dependency check, k0s install etc)

# Your existing install_missing_tools function can be refactored to handle full TOOLS list here...

echo "🚀 Starting k0s with Cilium installation process..."

install_missing_tools
check_prerequisites
dependency_check
install_k0s

if ! check_cilium; then
  install_cilium
fi

test_basic_connectivity
deploy_cilium_connectivity_check

echo "🎉 All done!"
