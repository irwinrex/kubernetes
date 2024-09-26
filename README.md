# Kubernetes Deployment Guide

### Note: Testing the Files for Full Operation

This guide will help you set up Kubernetes components, including DaemonSets (like node exporter) and StatefulSets (like databases), using either Minikube or K3s.

## Prerequisites

Ensure you have the following components installed:

- **Docker**  
  [Install Docker for Linux](https://docs.docker.com/desktop/install/linux-install/)

- **Linux Environment**  
  For Windows users, please use **WSL2**.

## K3 Installation Instructions

Clone the repository and execute the necessary scripts:

```
git clone https://github.com/irwinrex/kubernetes.git
chmod +x shellscripts/*.sh
sh shellscripts/install_k3s.sh             # K3s Installation
sh shellscripts/install_helm.sh           # Install Helm
kubectl get pod -n kube-system
```

## Firewall Configuration
### Allow necessary ports through the firewall:


```
sudo ufw allow 6443/tcp               # Allow API Server port
sudo ufw allow from 10.42.0.0/16 to any # Allow traffic from Pods network
sudo ufw allow from 10.43.0.0/16 to any # Allow traffic from Services network
```


## Minikube Installation Instructions
If using Minikube, configure Docker to use Minikube's Docker daemon:


```
chmod +x shellscripts/*.sh
sh shellscripts/install_minikube.sh       # Install minikube
sh shellscripts/install_helm.sh           # Install Helm
kubectl get pod -n kube-system
eval $(minikube docker-env)
```


# Excute to Run the Application

Pull and Deploy Docker Image

```
docker pull dockerrexxzz/dj:v1
kubectl apply -f all.yml
kubectl get pod
```

## Accessing the Application
### Forward the service port to access the application:


```
kubectl port-forward svc/sample-service 8000:8000
```

Ingress Setup (Minikube only)
Enable the Ingress addon in Minikube and configure the host:


```
minikube addon enable ingress           # Skip this for K3s
sudo nano /etc/hosts                    # Add domain mapping
```

# Add the following line:

127.0.0.1 sample-ing.local
Access the application via:


```
curl -L http://sample-ing.local
```

# or open in a browser:

http://sample-ing.local

## Uninstallation Instructions

To uninstall any component, navigate to the shellscripts directory and execute the corresponding script:


```
cd shellscripts
sh uninstall_<component>.sh
```

Replace <component> with the desired script name, for example, uninstall_k3.sh.


Note :

## Added Cilium

~ Cilium efficiently manages Kubernetes networking to reduce latency, even with the default setup:

~ eBPF-Powered Networking: High-performance packet processing in the Linux kernel reduces overhead and network hops.

~ Efficient Load Balancing: eBPF-based L4 load balancing ensures smooth traffic distribution across pods, avoiding traditional bottlenecks.

~ Optimized Network Policies: Cilium enforces network policies within the kernel for minimal performance impact.

~ Direct Pod Communication: Cilium allows direct pod-to-pod traffic, reducing network hops and improving latency.