#!/bin/bash

# Check if k0s is installed by checking the status of the k0scontroller service
if systemctl is-active --quiet k0scontroller; then
    echo "Stopping k0scontroller service..."
    sudo systemctl stop k0scontroller
    sudo systemctl disable k0scontroller
else
    echo "k0scontroller is not running."
fi

# Remove the k0s service
echo "Removing k0s service..."
sudo rm -f /etc/systemd/system/k0scontroller.service

# Reload systemd to recognize the service removal
sudo systemctl daemon-reload

# Clean up k0s data and binaries
echo "Removing k0s data and binaries..."
sudo rm -rf /var/lib/k0s
sudo rm -f /usr/local/bin/k0s

# Remove the kubeconfig file if it exists
if [ -f ~/.kube/config ]; then
    echo "Removing kubeconfig file..."
    rm -f ~/.kube/config
fi

# Optionally, remove the .kube directory if it's empty
if [ -d ~/.kube ] && [ -z "$(ls -A ~/.kube)" ]; then
    echo "Removing empty .kube directory..."
    rmdir ~/.kube
fi

echo "k0s uninstallation completed successfully."
