#!/bin/bash
set -euo pipefail

echo "⚠️  Starting cleanup process for k0s + Cilium environment..."

# --- Function to uninstall Cilium and related CRDs ---
uninstall_cilium() {
    echo "🧹 Uninstalling Cilium..."

    if helm ls -n kube-system | grep -q cilium; then
        helm uninstall cilium -n kube-system || true
    fi

    echo "⏳ Waiting for Cilium resources to terminate..."
    sleep 5

    echo "🧽 Cleaning up Cilium CRDs..."
    CRDS=$(kubectl get crds -o name | grep 'cilium' || true)
    if [[ -n "$CRDS" ]]; then
        kubectl delete $CRDS --ignore-not-found || true
    fi

    echo "🧽 Removing leftover Cilium components..."
    kubectl delete -n kube-system daemonset cilium --ignore-not-found || true
    kubectl delete -n kube-system deployment hubble-relay --ignore-not-found || true
    kubectl delete -n kube-system svc hubble-relay --ignore-not-found || true

    echo "🧽 Optionally removing kube-system namespace (not recommended)..."
    # kubectl delete ns kube-system --ignore-not-found || true

    echo "🧽 Removing Cilium CLI if installed..."
    sudo rm -f /usr/local/bin/cilium

    echo "✅ Cilium uninstalled."
}

# --- Function to uninstall k0s ---
uninstall_k0s() {
    echo "🧹 Uninstalling k0s..."

    if systemctl is-active --quiet k0scontroller.service; then
        sudo systemctl stop k0scontroller.service
    fi

    sudo k0s stop || true
    sleep 3
    sudo k0s reset --debug || true

    echo "🧽 Cleaning up k0s files and services..."
    sudo rm -rf /var/lib/k0s \
                /etc/systemd/system/k0s*.service \
                /usr/local/bin/k0s \
                /etc/k0s \
                /etc/systemd/system/k0scontroller.service

    echo "✅ k0s uninstalled."
}

# --- Function to uninstall kubectl ---
uninstall_kubectl() {
    echo "🧹 Uninstalling kubectl..."
    sudo rm -f /usr/local/bin/kubectl
    rm -rf ~/.kube
    echo "✅ kubectl removed."
}

# --- Function to uninstall Helm ---
uninstall_helm() {
    echo "🧹 Uninstalling Helm..."
    sudo rm -f /usr/local/bin/helm
    echo "✅ Helm removed."
}

# --- Function to uninstall yq (optional) ---
uninstall_yq() {
    if command -v yq &>/dev/null; then
        echo "🧹 Uninstalling yq..."
        sudo rm -f "$(command -v yq)"
        echo "✅ yq removed."
    fi
}

# --- Execute all uninstalls ---
uninstall_cilium
uninstall_k0s
uninstall_kubectl
uninstall_helm
uninstall_yq

echo "🎉 Uninstallation Completed Successfully!"
