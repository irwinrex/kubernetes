#!/bin/bash

# Download and install Minikube
echo "Downloading and installing Minikube..."
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube /usr/local/bin/

# Clean up the downloaded file
rm minikube

# Start Minikube using Docker as the driver
echo "Starting Minikube with Docker driver..."
minikube start --driver=docker

# Verify Minikube installation
if minikube status >/dev/null 2>&1; then
    echo "Minikube installed and running successfully using Docker."
else
    echo "Minikube installation failed."
fi