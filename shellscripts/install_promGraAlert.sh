#!/bin/bash

# Variables
NAMESPACE="monitoring"  # You can change this to your preferred namespace

# Step 1: Add the Prometheus Community Helm repository
echo "Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Step 2: Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Step 3: Create the namespace if it doesn't exist
echo "Creating namespace '$NAMESPACE' if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Step 4: Install the kube-prometheus-stack
echo "Installing kube-prometheus-stack in the '$NAMESPACE' namespace..."
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace $NAMESPACE \
    --set prometheus.prometheusSpec.replicaCount=1 \
    --set alertmanager.alertmanagerSpec.replicaCount=1 \
    --set grafana.replicaCount=1

# Step 5: Wait for the installation to complete
echo "Waiting for Prometheus and Grafana to be ready..."

# Wait for Prometheus deployment
kubectl wait --for=condition=available --timeout=600s deployment/kube-prometheus-stack-operator -n $NAMESPACE

# Wait for Grafana deployment
kubectl wait --for=condition=available --timeout=600s deployment/kube-prometheus-stack-grafana -n $NAMESPACE

# Step 6: Output access information
echo "Installation complete!"

# Step 7: Get the Grafana admin password
echo "Retrieving the Grafana admin password..."
GRAFANA_PASSWORD=$(kubectl get secret --namespace $NAMESPACE kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)

# Print the Grafana admin password
echo "Grafana Admin Password: $GRAFANA_PASSWORD"

# Step 8: Provide information to access Grafana
echo "You can access Grafana at:"
echo "http://<grafana-service-ip>:80"  # Replace <grafana-service-ip> with actual service IP
echo "To log in, use:"
echo "Username: admin"
echo "Password: $GRAFANA_PASSWORD"
