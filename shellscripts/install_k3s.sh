#!/bin/bash

# Set flags for exit on error and pipefail
set -euo pipefail

# Function to wait for K3s to be ready
wait_for_k3s() {
    echo "Waiting for K3s to become ready..."
    for i in {1..10}; do
        if kubectl get nodes >/dev/null 2>&1; then
            echo "K3s is ready."
            return
        fi
        echo "K3s not ready yet. Waiting 10 seconds..."
        sleep 10
    done
    echo "K3s did not become ready in time!"
    exit 1
}

# Function to install K3s
install_k3s() {
    echo "Installing K3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--cluster-init --flannel-backend=none --disable=traefik,metrics-server,network-policy" sh -


    # Wait for K3s to start
    echo "Waiting for K3s to start..."
    sleep 20

    # Create .kube directory if it doesn't exist
    mkdir -p ~/.kube/

    # Copy the K3s kubeconfig file to the user's kube config file
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    # Update the Kubeconfig file to use the host's IP
    sudo chmod 600 ~/.kube/config
    sudo chown $(whoami):$(whoami) ~/.kube/config /etc/rancher/k3s/k3s.yaml

    # Export KUBECONFIG
    export KUBECONFIG=~/.kube/config

    # Verify K3s installation
    wait_for_k3s
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
    export KUBECONFIG=~/.kube/config
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    helm install cilium cilium/cilium --version 1.16.2 \
        --namespace kube-system \
        --set operator.replicas=1 \
        --set kubeProxyReplacement=true \
        --set hostService.enabled=true
    
    echo "Waiting for Cilium to initialize..."
    sleep 30

    # Verify Cilium installation
    kubectl -n kube-system get pods -l k8s-app=cilium
}

# Function to install Metrics Server
install_metrics() {
    echo "Installing Metrics Server..."
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update

    # Install the Metrics Server with the --kubelet-insecure-tls argument
    helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

    # Wait for 30 seconds to allow Metrics Server to initialize
    echo 'Waiting for Metrics Server to initialize...'
    sleep 30

    # Verify Metrics Server installation
    kubectl -n kube-system get pods -l k8s-app=metrics-server
}

# Main script execution
install_kubectl
install_k3s
install_helm
install_cilium
install_metrics

# Confirm installation completed
echo "Installation Completed Successfully!"
