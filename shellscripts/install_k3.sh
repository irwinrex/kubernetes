#!/bin/bash

# username=${whoami}

# Download and install K3s
curl -sfL https://get.k3s.io | sh -s - --disable traefik,metrics-server

# Wait for K3s to start
echo "Waiting for K3s to start..."
sleep 20

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube/

# Remove existing kube config file if it exists
if [ -f ~/.kube/config ]; then
    rm ~/.kube/config
fi

# Create a symbolic link to the K3s kubeconfig file
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Change Permission
chmod 700 ~/.kube/config
sudo chmod 700 /etc/rancher/k3s/k3s.yaml
# sudo chown $username:$username ~/.kube/config

# Verify K3s installation
sudo k3s kubectl get nodes

# Provide feedback on completion
echo "K3s installation complete! Kubernetes is running and kube config is set up."
