#!/bin/bash

# Stop Minikube if it's running
echo "Stopping Minikube..."
minikube stop

# Delete the Minikube cluster
echo "Deleting Minikube cluster..."
minikube delete

# Remove the Minikube binary
echo "Removing Minikube binary..."
sudo rm -f /usr/local/bin/minikube

# Remove any Minikube configuration and data
echo "Removing Minikube configuration and data..."
sudo rm -rf ~/.minikube
sudo rm -rf /etc/kubernetes/manifests
sudo rm -rf /var/lib/minikube

# Check if Minikube is completely removed
if command -v minikube >/dev/null 2>&1; then
    echo "Minikube uninstallation failed."
else
    echo "Minikube uninstalled successfully."
fi