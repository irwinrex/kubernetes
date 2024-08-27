#!/bin/bash

# Set namespace for Traefik
NAMESPACE="kube-system"

# Add Traefik Helm repository
echo "Adding Traefik Helm repository..."
helm repo add traefik https://traefik.github.io/helm-charts

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Install Traefik using Helm
echo "Installing Traefik..."
helm install traefik traefik/traefik --namespace $NAMESPACE --create-namespace

# Wait for Traefik pods to be up and running
echo "Waiting for Traefik pods to be up and running..."
kubectl rollout status deployment/traefik -n $NAMESPACE

# Check the status of Traefik pods
echo "Checking Traefik pods..."
kubectl get pods -n $NAMESPACE

echo "Traefik installation and pod status check completed."
