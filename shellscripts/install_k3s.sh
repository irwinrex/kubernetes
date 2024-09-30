#!/bin/bash

# Set flags for exit on error and pipefail
set -euo pipefail

# Function to install K3s
install_k3s() {
    echo "Installing K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none --disable=traefik,metrics-server,network-policy --datastore-endpoint="etcd"' sh -

    # Wait for K3s to start
    echo "Waiting for K3s to start..."
    sleep 20

    # Create .kube directory if it doesn't exist
    mkdir -p ~/.kube/

    # Copy the K3s kubeconfig file to the user's kube config file
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    # sed -i "s/127.0.0.1/$(hostname -i | awk '{print $1}')/g" ~/.kube/config
    sudo chmod 600 ~/.kube/config
    sudo chown $(whoami):$(whoami) ~/.kube/config

    # Export KUBECONFIG
    export KUBECONFIG=~/.kube/config

    # Verify K3s installation
    kubectl get nodes
}

# Function to install kubectl
install_kubectl() {
    echo "Installing kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"

    # Verify the checksum of kubectl
    echo "Verifying kubectl checksum..."
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Clean up kubectl files
    rm -rvf kubectl kubectl.sha256

    # Verify kubectl installation
    kubectl version --client --output=yaml
}

# Function to install Helm
install_helm() {
    echo "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x get_helm.sh
    ./get_helm.sh
    rm -f get_helm.sh

    # Verify Helm installation
    echo "Verifying Helm installation..."
    if helm version >/dev/null 2>&1; then
        echo "Helm installed successfully."
    else
        echo "Helm installation failed."
        exit 1
    fi
}

# Function to install Cilium
install_cilium() {
    echo "Installing Cilium..."
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

    # Cilium installation
    cilium install --version 1.16.2 --set=ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16" --set kubeProxyReplacement=true

    # Verify Cilium installation
    cilium version
    cilium status --wait
    # cilium connectivity test

    # Install Cilium Hubble
    # echo "Installing Cilium Hubble..."
    # cilium hubble enable --ui
    # cilium hubble ui
}

# Function to install Metrics Server
install_metrics() {
    echo "Installing Metrics Server..."
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update

    # Install the Metrics Server with the --kubelet-insecure-tls argument
    helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

    # Wait for 30 seconds to allow Metrics Server to initialize
    echo 'Waiting for 30 seconds...'
    sleep 30
}

# Main script execution
install_k3s
install_kubectl
install_helm
install_cilium
install_metrics

# Confirm installation completed
echo "Installation Completed Successfully!"
