#!/bin/bash

# Stop k3s service if running
echo "Stopping k3s service..."
sudo systemctl stop k3s

# Disable k3s service
echo "Disabling k3s service..."
sudo systemctl disable k3s

# Remove k3s binary
if [ -f "/usr/local/bin/k3s" ]; then
    echo "Removing k3s binary from /usr/local/bin..."
    sudo rm /usr/local/bin/k3s
elif [ -f "/usr/bin/k3s" ]; then
    echo "Removing k3s binary from /usr/bin..."
    sudo rm /usr/bin/k3s
else
    echo "k3s binary not found!"
fi

# Remove k3s configuration and data directories
echo "Removing k3s configuration and data..."
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s

# Remove k3s systemd service file (if exists)
if [ -f "/etc/systemd/system/k3s.service" ]; then
    echo "Removing k3s systemd service file..."
    sudo rm /etc/systemd/system/k3s.service
else
    echo "k3s systemd service file not found!"
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "k3s has been successfully removed!"

# Uninstall Cilium if installed
echo "Uninstalling Cilium..."
if kubectl get pods -n kube-system | grep -q "cilium"; then
    kubectl delete --all namespaces cilium
    echo "Cilium has been successfully uninstalled!"
else
    echo "Cilium is not installed!"
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
  
  # Check the CRD still exists
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

# (Optionally) Check if kubectl is installed and uninstall
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

echo "K8s have been successfully removed!"
