## Kubernetes Commands

k8 : minikube

```
git clone https://github.com/irwinrex/kubernetes.git
cd kubernetes
minikube start
eval $(minikube docker-env)
docker pull dockerrexxzz/dj:latest
chmod +x install_metrics_server.sh
sh install_metrics_server.sh
kubectl apply -f all.yml
minikube addon enable ingress
kubectl apply -f ingress.yml
kubectl get pod -n ingress-nginx
kubectl get pod -A | grep nginx --> check the container is running
kubectl get ingress --> copy the address
sudo nano /etc/hosts --> paste it and name it foo.bar.com (domain mapping in local)
curl -L http://foo.bar.com
```