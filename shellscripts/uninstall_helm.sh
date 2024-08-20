#!/bin/bash

# Check if Helm is installed
if ! command -v helm >/dev/null 2>&1; then
    echo "Helm is not installed on this system."
    exit 1
fi

# Remove Helm binary
echo "Removing Helm binary..."
sudo rm -f /usr/local/bin/helm

# Optionally remove Helm-related directories
echo "Removing Helm configuration and data directories..."
sudo rm -rf ~/.helm
sudo rm -rf /usr/local/helm

# Verify Helm uninstallation
if command -v helm >/dev/null 2>&1; then
    echo "Helm uninstallation failed."
else
    echo "Helm uninstalled successfully."
fi
