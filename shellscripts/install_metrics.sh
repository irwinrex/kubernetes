#!/bin/bash

# Add the Metrics Server Helm repository and update it
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install the Metrics Server with the --kubelet-insecure-tls argument
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Wait for 30s
echo 'Wait for 30 Seconds'

sleep 30
