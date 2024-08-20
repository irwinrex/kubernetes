#!/bin/bash

# Download Helm installation script
echo "Downloading Helm installation script..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Make the installation script executable
chmod +x get_helm.sh

# Run the Helm installation script
echo "Installing Helm..."
./get_helm.sh

# Verify Helm installation
if helm version >/dev/null 2>&1; then
    echo "Helm installed successfully."
else
    echo "Helm installation failed."
fi

# Clean up the installation script
rm -f get_helm.sh
