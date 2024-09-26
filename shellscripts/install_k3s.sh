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

# Add the Metrics Server Helm repository and update it
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install the Metrics Server with the --kubelet-insecure-tls argument
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Wait for 30s
echo 'Wait for 30 Seconds'

sleep 30

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
rm -rvf cilium-linux-*.tar.gz.sha256sum
rm -rvf cilium-linux-*.tar.gz

# Install Cilium using the k3s default podCIDR
cilium install --set=ipam.operator.clusterPoolIPv4PodCIDRList="10.42.0.0/16"
