#!/bin/bash

# Download and install K3s with specified options
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none --disable=traefik,metrics-server,network-policy --datastore-endpoint="etcd"' sh -

# Wait for K3s to start
echo "Waiting for K3s to start..."
sleep 20

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube/

# Copy the K3s kubeconfig file to the user's kube config file
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Change permissions for the kube config file
chmod 600 ~/.kube/config

# Change ownership of the kube config file to the current user
sudo chown $(whoami):$(whoami) ~/.kube/config

# Verify K3s installation
kubectl get nodes

# Provide feedback on completion
echo "K3s installation complete! Kubernetes is running and kube config is set up."

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod 700 kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl
rm -rvf kubectl
rm -rvf kubectl.sha256
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
fi

# Clean up the installation script
rm -f get_helm.sh

# Installing Cilium by helm
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium --version 1.16.2 \
   --namespace kube-system \
   --set operator.replicas=1

# Add the Metrics Server Helm repository and update it
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install the Metrics Server with the --kubelet-insecure-tls argument
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Wait for 30s
echo 'Wait for 30 Seconds'

sleep 30

echo "Installation Completed"
