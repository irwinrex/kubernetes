#!/bin/bash

# Add the Metrics Server Helm repository and update it
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install the Metrics Server with the --kubelet-insecure-tls argument
helm install metrics-server metrics-server/metrics-server --namespace kube-system --set args[0]=--kubelet-insecure-tls

# Wait until the Metrics Server pod is in the Running and Ready state
echo "Waiting for Metrics Server pod to be in Running and Ready state..."
while true; do
  # Get the name of the Metrics Server pod
  pod_name=$(kubectl get pods -n kube-system -l "app.kubernetes.io/name=metrics-server" -o jsonpath="{.items[0].metadata.name}")
  
  # Get the current status and readiness of the Metrics Server pod
  pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}")
  pod_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}")

  if [ "$pod_status" == "Running" ] && [ "$pod_ready" == "True" ]; then
    echo "Metrics Server pod is up and running."
    break
  else
    echo "Metrics Server pod is not ready yet. Current status: $pod_status. Readiness: $pod_ready. Retrying in 5 seconds..."
    sleep 10

    # Recheck after sleep
    pod_status=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.phase}")
    pod_ready=$(kubectl get pod "$pod_name" -n kube-system -o jsonpath="{.status.conditions[?(@.type=='Ready')].status}")

    if [ "$pod_status" == "Running" ] && [ "$pod_ready" == "True" ]; then
      echo "Metrics Server pod is up and running after recheck."
      break
    fi
  fi
done
