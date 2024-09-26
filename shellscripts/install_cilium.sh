#!/bin/bash

# Detect the latest Cilium CLI version
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

# Detect system architecture (amd64 or arm64)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH=arm64
fi

# Download the Cilium CLI binary and checksum
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify checksum
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

# Extract Cilium CLI to /usr/local/bin
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

# Cleanup downloaded files
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Install Cilium using the k3s default podCIDR
cilium install --set=ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16"
