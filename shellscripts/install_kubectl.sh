install_kubectl() {
    echo "Installing kubectl..."
    local KUBECTL_VERSION
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl" \
         -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
    
    echo "Verifying kubectl checksum..."
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl kubectl.sha256
    echo "kubectl installed successfully."
}

install_kubectl