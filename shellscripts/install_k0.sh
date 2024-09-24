#!/bin/bash

# Check if k0s is already installed by checking the status of the k0scontroller service
if systemctl is-active --quiet k0scontroller; then
    echo "k0scontroller is already running. Restarting the service..."
    sudo systemctl restart k0scontroller
else
    echo "k0scontroller is not running. Proceeding with installation..."

    # Stop k0s if it's already running to avoid the "Text file busy" error
    sudo k0s stop || true

    # Ensure no other k0s process is locking the file
    sudo pkill -f k0s || true

    # Download and install k0s
    curl -sSLf https://get.k0s.sh | sudo sh

    # Install k0s as a single-node controller
    sudo k0s install controller --single

    # Start k0s
    sudo k0s start

    # Wait for a few seconds to ensure k0s is up and running
    sleep 10

    # Create .kube directory if it doesn't exist
    mkdir -p ~/.kube/

    # Remove existing kube config file if it exists
    if [ -f ~/.kube/config ]; then
        rm ~/.kube/config
    fi

    # Create a symbolic link to the k0s kubeconfig file
    ln -s /var/lib/k0s/pki/admin.conf ~/.kube/config

    # Change permissions for the kubeconfig file
    sudo chmod 600 ~/.kube/config
    sudo chmod 600 /var/lib/k0s/pki/admin.conf

    # Ensure the current user owns the kubeconfig file
    sudo chown $(whoami):$(whoami) ~/.kube/config

    echo "k0s installation completed successfully."
fi
