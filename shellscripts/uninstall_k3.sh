#!/bin/bash

# Check if K3s is installed
if ! command -v k3s >/dev/null 2>&1; then
    echo "K3s is not installed on this system."
    exit 1
fi

# Uninstall K3s
echo "Uninstalling K3s..."
/usr/local/bin/k3s-uninstall.sh

# Remove the kube config file if it exists
if [ -f ~/.kube/config ]; then
    echo "Removing ~/.kube/config..."
    rm -f ~/.kube/config
fi

# Optionally remove the ~/.kube directory if empty
if [ -d ~/.kube ] && [ -z "$(ls -A ~/.kube)" ]; then
    echo "Removing empty ~/.kube directory..."
    rmdir ~/.kube
fi

# Verify K3s uninstallation
echo "K3s uninstalled successfully."
