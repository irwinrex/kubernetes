#!/bin/bash

# Exit on error and enable pipefail
set -euo pipefail

# Function to check if a command exists
check_command_exists() {
    command -v "$1" &> /dev/null
}

# Uninstall Cilium if installed
echo "Uninstalling Cilium..."
if check_command_exists "kubectl" && kubectl get pods -n kube-system | grep -q "cilium"; then
    helm uninstall cilium --namespace kube-system || echo "Failed to uninstall Cilium."
    echo "Cilium has been successfully uninstalled!"
else
    echo "Cilium is not installed or kubectl is unavailable."
fi

# Uninstall Helm
echo "Uninstalling Helm..."
if check_command_exists "helm"; then
    # Remove Helm from common installation paths
    if [ -f "/usr/local/bin/helm" ]; then
        sudo rm /usr/local/bin/helm
        echo "Removed Helm from /usr/local/bin."
    fi

    # Optionally remove Helm home directory
    if [ -d "$HOME/.helm" ]; then
        rm -rf "$HOME/.helm"
        echo "Removed Helm configuration from $HOME/.helm."
    fi

    echo "Helm has been uninstalled."
else
    echo "Helm is not installed."
fi

# Remove any remaining Kubernetes configuration (optional)
echo "Removing Kubernetes configuration..."
if [ -d "$HOME/.kube" ]; then
    rm -rf "$HOME/.kube"
    echo "Removed Kubernetes configuration from $HOME/.kube."
fi

# Stop and disable k3s service if running (done last)
echo "Stopping and disabling k3s service..."
if check_command_exists "systemctl"; then
    sudo systemctl stop k3s || echo "k3s service not running."
    sudo systemctl disable k3s || echo "k3s service was not enabled."
else
    echo "systemctl not found. Skipping k3s service management."
fi

# Remove k3s binary
echo "Removing k3s binary..."
if [ -f "/usr/local/bin/k3s" ]; then
    sudo rm /usr/local/bin/k3s
    echo "Removed k3s binary from /usr/local/bin."
elif [ -f "/usr/bin/k3s" ]; then
    sudo rm /usr/bin/k3s
    echo "Removed k3s binary from /usr/bin."
else
    echo "k3s binary not found!"
fi

# Remove k3s configuration and data directories
echo "Removing k3s configuration and data..."
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s

# Remove k3s systemd service file (if exists)
if [ -f "/etc/systemd/system/k3s.service" ]; then
    echo "Removing k3s systemd service file..."
    sudo rm /etc/systemd/system/k3s.service
else
    echo "k3s systemd service file not found!"
fi

# Reload systemd daemon
if check_command_exists "systemctl"; then
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
fi

# Uninstall kubectl
echo "Uninstalling kubectl..."
if check_command_exists "kubectl"; then
    # Attempt to remove kubectl from common installation paths
    if [ -f "/usr/local/bin/kubectl" ]; then
        sudo rm /usr/local/bin/kubectl
        echo "Removed kubectl from /usr/local/bin."
    fi
    if [ -f "/usr/bin/kubectl" ]; then
        sudo rm /usr/bin/kubectl
        echo "Removed kubectl from /usr/bin."
    fi
else
    echo "kubectl is not installed."
fi

# Uninstall any remaining Kubernetes packages
echo "Removing remaining Kubernetes packages..."
if check_command_exists "apt"; then
    sudo apt-get remove --purge -y kubelet kubeadm kubectl kubernetes-cni kubelet kubectl
    sudo apt-get autoremove -y
fi

# Remove remaining Kubernetes directories
echo "Removing any remaining Kubernetes directories..."
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd
sudo rm -rf /etc/cni
sudo rm -rf /var/lib/cni
sudo rm -rf /var/run/kubernetes
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/run/cilium

# Remove Cilium configuration and data directories if they exist
echo "Removing Cilium configuration and data..."
sudo rm -rf /var/lib/cilium
sudo rm -rf /etc/cilium

echo "Kubernetes, K3s, and related components have been successfully removed!"
