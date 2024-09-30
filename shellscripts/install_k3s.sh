#!/bin/bash

# Set flags for exit on error and pipefail
set -euo pipefail

# Download and install K3s with specified options
echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none --disable=traefik,metrics-server,network-policy --datastore-endpoint="etcd"' sh -

# Wait for K3s to start
echo "Waiting for K3s to start..."
sleep 20

# Get the server's IP address (adjust this if you have multiple IPs)
SERVER_IP="$(hostname -i | awk '{print $1}')"  # This grabs the first IP address returned

# Create .kube directory if it doesn't exist
echo "Setting up kube config..."
mkdir -p ~/.kube/

# Copy the K3s kubeconfig file to the user's kube config file
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update kubeconfig to use the server's IP for API server access from remote machines
sed -i "s/127.0.0.1/$SERVER_IP/g" ~/.kube/config

# Set appropriate permissions for kubeconfig
chmod 600 ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config

# Verify K3s installation
kubectl get nodes

# Provide feedback on completion
echo "K3s installation complete! Kubernetes is running and kube config is set up."
echo "You can access the cluster remotely using the kubeconfig. Server IP: $SERVER_IP"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Verify the checksum of kubectl
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clean up kubectl files
rm -rvf kubectl kubectl.sha256

# Verify kubectl installation
kubectl version --client --output=yaml

# Download Helm installation script
echo "Downloading Helm installation script..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Make the installation script executable
chmod +x get_helm.sh

# Run the Helm installation script
echo "Installing Helm..."
./get_helm.sh

# Verify Helm installation
if helm version >/dev/null 2>&1; then
    echo "Helm installed successfully."
else
    echo "Helm installation failed."
    exit 1
fi

# Clean up the installation script
rm -f get_helm.sh

# Installing Cilium via Helm
echo "Installing Cilium..."
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.2 \
   --namespace kube-system \
   --set operator.replicas=1

# Add the Metrics Server Helm repository and update it
echo "Installing Metrics Server..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install the Metrics Server with the --kubelet-insecure-tls argument
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Wait for 30 seconds to allow Metrics Server to initialize
echo 'Waiting for 30 seconds...'
sleep 30

# Confirm installation completed
echo "Installation Completed Successfully!"
