#!/bin/bash

# Uninstall the Metrics Server using Helm
helm uninstall metrics-server --namespace kube-system

# Check if the Metrics Server is successfully uninstalled
if helm list --namespace kube-system | grep -q metrics-server; then
    echo "Metrics Server uninstallation failed."
else
    echo "Metrics Server uninstalled successfully."
fi
