#!/bin/bash

# Uninstall the Metrics Server release
echo "Uninstalling Metrics Server..."
helm uninstall metrics-server --namespace kube-system

# Wait for the Metrics Server resources to be fully removed
echo "Waiting for Metrics Server resources to be removed..."
while true; do
  # Check if any pods with the Metrics Server label still exist
  pod_count=$(kubectl get pods -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if any services with the Metrics Server label still exist
  service_count=$(kubectl get services -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if any deployments with the Metrics Server label still exist
  deployment_count=$(kubectl get deployments -n kube-system -l "app.kubernetes.io/name=metrics-server" --no-headers | wc -l)
  
  # Check if the CRD still exists
  crd_exists=$(kubectl get apiservice v1beta1.metrics.k8s.io --ignore-not-found)

  if [ "$pod_count" -eq 0 ] && [ "$service_count" -eq 0 ] && [ "$deployment_count" -eq 0 ] && [ -z "$crd_exists" ]; then
    echo "Metrics Server has been successfully uninstalled and cleaned up."
    break
  else
    echo "Metrics Server resources still exist. Waiting 10 seconds before retrying..."
    sleep 10
  fi
done

echo "Cleaning up any remaining CRDs if needed..."
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found

echo "Metrics Server uninstallation script completed."
