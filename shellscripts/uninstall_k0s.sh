#!/bin/bash

set -euo pipefail  # Exit on error and undefined variables

# Function to uninstall Cilium
uninstall_cilium() {
    echo "Uninstalling Cilium..."
    if helm ls -n kube-system | grep -q cilium; then
        helm uninstall cilium -n kube-system
        echo "Waiting for Cilium resources to terminate..."
        kubectl delete crd ciliumnetworkpolicies.cilium.io --ignore-not-found
        kubectl delete crd ciliumendpoints.cilium.io --ignore-not-found
        kubectl delete crd ciliumidentities.cilium.io --ignore-not-found
        kubectl delete crd ciliumnodes.cilium.io --ignore-not-found
        kubectl delete crd ciliumexternalworkloads.cilium.io --ignore-not-found
        kubectl delete ns kube-system --ignore-not-found
        echo "Cilium uninstalled successfully."
    else
        echo "Cilium is not installed. Skipping..."
    fi
}

# Function to stop and uninstall k0s
uninstall_k0s() {
    echo "Stopping k0s..."
    sudo systemctl stop k0scontroller.service || true
    sudo k0s stop || true

    sleep 5

    echo "Uninstalling k0s..."
    sudo k0s reset --debug || true

    echo "Removing k0s system files..."
    sudo rm -rf /var/lib/k0s /etc/systemd/system/k0s*.service ~/.kube/config \
                /etc/systemd/system/k0scontroller.service /usr/local/bin/k0s

    echo "k0s uninstalled successfully."
}

# Function to uninstall kubectl
uninstall_kubectl() {
    echo "Removing kubectl..."
    sudo rm -f /usr/local/bin/kubectl
    sudo rm -rf ~/.kube
    echo "kubectl removed successfully."
}

# Function to uninstall Helm
uninstall_helm() {
    echo "Removing Helm..."
    sudo rm -f /usr/local/bin/helm
    echo "Helm removed successfully."
}

# Main script execution
uninstall_cilium
uninstall_k0s
uninstall_kubectl
uninstall_helm

# Confirm uninstallation completed
echo "Uninstallation Completed Successfully!"
