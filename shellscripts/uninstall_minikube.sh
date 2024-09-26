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

# Uninstall the Metrics Server release
echo "Uninstalling Metrics Server..."
helm uninstall metrics-server --namespace kube-system

# Wait for the Metrics Server resources to be fully removed
echo "Waiting for Metrics Server resources to be removed..."
while true; do
  # Check if any pods with the Metrics Server label still exist
  pod_count=$(kubectl get pods -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if any services with the Metrics Server label still exist
  service_count=$(kubectl get services -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if any deployments with the Metrics Server label still exist
  deployment_count=$(kubectl get deployments -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if the CRD still exists
  crd_exists=$(kubectl get apiservice v1beta1.metrics.k8s.io --ignore-not-found)

  if [ "$pod_count" -eq 0 ] && [ "$service_count" -eq 0 ] && [ "$deployment_count" -eq 0 ] && [ -z "$crd_exists" ]; then
    echo "Metrics Server has been successfully uninstalled and cleaned up."
    break
  else
    echo "Metrics Server resources still exist. Waiting 10 seconds before retrying..."
    sleep 10
  fi
done

echo "Cleaning up any remaining CRDs if needed..."
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found

echo "Metrics Server uninstallation script completed."

# Function to check if kubectl is installed
check_kubectl_installed() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed."
        exit 1
    fi
}

# Function to uninstall kubectl
uninstall_kubectl() {
    echo "Uninstalling kubectl..."
    
    # Attempt to remove kubectl from common installation paths
    if [ -f "/usr/local/bin/kubectl" ]; then
        sudo rm /usr/local/bin/kubectl
        echo "Removed kubectl from /usr/local/bin."
    fi
    
    if [ -f "$HOME/.kubectl" ]; then
        rm "$HOME/.kubectl"
        echo "Removed kubectl from $HOME/.kubectl."
    fi

    # Optional: Remove kubeconfig and other kubectl-related files
    if [ -d "$HOME/.kube" ]; then
        rm -rf "$HOME/.kube"
        echo "Removed kubectl configuration from $HOME/.kube."
    fi

    echo "kubectl has been uninstalled."
}

# Start script
check_kubectl_installed
uninstall_kubectl

echo "Kubectl has been uninstalled successfully."

echo "k8s removed successfully."