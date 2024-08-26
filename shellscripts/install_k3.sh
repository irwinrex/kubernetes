#!/bin/bash

# Download and install K3s
curl -sfL https://get.k3s.io | sh -s - --disable traefik,metrics-server


# Wait for K3s to start
echo "Waiting for K3s to start..."
sleep 20

# Create .kube directory if it doesn't exist
mkdir -p ~/.kube/

# Create the kube config file
touch ~/.kube/config

# Copy the K3s kubeconfig file to the .kube/config file
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Change Permission
chmod 600 ~/.kube/config

# Verify K3s installation
sudo k3s kubectl get nodes

# Provide feedback on completion
echo "K3s installation complete! Kubernetes is running and kube config is set up."
