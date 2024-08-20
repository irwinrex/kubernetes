#!/bin/bash

# Download Helm installation script
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Make the Helm installation script executable
chmod 700 get_helm.sh

# Run the Helm installation script
./get_helm.sh

# Add the metrics-server Helm repository
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

# Update the Helm repositories
helm repo update

# Install the metrics-server in the kube-system namespace with insecure TLS option
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Clean up by removing the Helm installation script
rm -f get_helm.sh

echo "Metrics Server installation complete!"