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

# Install kubectl

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod 700 kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl
rm -rvf kubectl
rm -rvf kubectl.sha256
kubectl version --client --output=yaml