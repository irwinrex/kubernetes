#!/bin/bash

# Variables
NAMESPACE="monitoring"  # Change this to your namespace if different
RELEASE_NAME="my-kube-prometheus-stack"

# Step 1: Uninstall the Helm release
echo "Uninstalling Helm release '$RELEASE_NAME' from the '$NAMESPACE' namespace..."
helm uninstall $RELEASE_NAME --namespace $NAMESPACE

# Step 2: Optionally, delete the namespace
echo "Do you want to delete the namespace '$NAMESPACE'? (y/n)"
read -r DELETE_NAMESPACE

if [[ "$DELETE_NAMESPACE" == "y" ]]; then
    echo "Deleting namespace '$NAMESPACE'..."
    kubectl delete namespace $NAMESPACE
else
    echo "Skipping namespace deletion."
fi

# Step 3: Confirm uninstallation
echo "Uninstallation complete!"
