#!/bin/bash

# Stop k0s service if running
echo "Stopping k0s service..."
sudo systemctl stop k0scontroller

# Disable k0s service
echo "Disabling k0s service..."
sudo systemctl disable k0scontroller

# Remove k0s binary
if [ -f "/usr/local/bin/k0s" ]; then
    echo "Removing k0s binary from /usr/local/bin..."
    sudo rm /usr/local/bin/k0s
elif [ -f "/usr/bin/k0s" ]; then
    echo "Removing k0s binary from /usr/bin..."
    sudo rm /usr/bin/k0s
else
    echo "k0s binary not found!"
fi

# Remove k0s configuration and data directories
echo "Removing k0s configuration and data..."
sudo rm -rf /var/lib/k0s
sudo rm -rf /etc/k0s

# Remove k0s systemd service file (if exists)
if [ -f "/etc/systemd/system/k0scontroller.service" ]; then
    echo "Removing k0s systemd service file..."
    sudo rm /etc/systemd/system/k0scontroller.service
else
    echo "k0s systemd service file not found!"
fi

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "k0s has been successfully removed!"
