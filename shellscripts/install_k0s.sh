#!/bin/bash
set -euo pipefail

### Function to check required tool installation and install if missing
dependency_check() {
    for cmd in kubectl helm cilium; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "$cmd is not installed. Installing $cmd..."
            if [ "$cmd" = "kubectl" ]; then
                KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
                curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
                sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                rm -f kubectl
            elif [ "$cmd" = "helm" ]; then
                curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
                chmod +x get_helm.sh
                ./get_helm.sh
                rm -f get_helm.sh
            elif [ "$cmd" = "cilium" ]; then
                echo "Cilium CLI is not required for this setup. Skipping installation."
            fi
        fi
    done
}

### Enhanced k0s Installation Function
install_k0s() {
    if ! command -v k0s >/dev/null; then
        echo "Installing k0s..."
        curl -sSLf https://get.k0s.sh | sudo sh
    fi

    # Install controller with disable-components flag
    sudo k0s install controller --single --disable-components kube-proxy,coredns,konnectivity-server,metrics-server

    sudo k0s start

    # Wait for k0s to generate admin.conf
    while [ ! -f "/var/lib/k0s/pki/admin.conf" ]; do
        echo "Waiting for admin.conf to be generated..."
        sleep 5
    done

    # Handle kubeconfig properly
    mkdir -p ~/.kube
    sudo cp /var/lib/k0s/pki/admin.conf ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    export KUBECONFIG=~/.kube/config

    # Wait for core components
    until kubectl get nodes; do sleep 5; done
}

### Improved Cilium Installation
install_cilium() {
    helm repo add cilium https://helm.cilium.io/
    helm repo update

    # Set correct k0s API server details for Cilium
    K8S_API_IP=$(hostname -I | awk '{print $1}')

    helm install cilium cilium/cilium --version 1.17.1 \
   --namespace kube-system \
   --set kubeProxyReplacement=false \
   --set operator.replicas=1

    # Wait for cilium pods to be ready
    kubectl -n kube-system wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s
}

### Main script execution
dependency_check
install_k0s
install_cilium

# Confirm installation completed
echo "k0s and Cilium Installation Completed Successfully!"

sleep 240
echo "Run Cilium connectivity test:"
kubectl exec -n kube-system ds/cilium -- cilium connectivity test