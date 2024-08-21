note : Testing the files to fully operatable 

Working on : Daemon set ( node exporter, etc.. )
             statefull set ( Database )

## Kubernetes Commands

k8 : minikube or k3

Components:

~ Docker --> https://docs.docker.com/desktop/install/linux-install/

~ Linux --> Windows User ( Please use wsl2 )

```
git clone https://github.com/irwinrex/kubernetes.git
chmod +x shellscripts/*.sh
sh shellscripts/install_k3.sh or sh shellscripts/install_minikube.sh
sh shellscripts/install_helm.sh
sh shellscripts/install_metrics.sh
eval $(minikube docker-env)       # if you install k3 please skip this
docker pull dockerrexxzz/dj:latest
kubectl apply -f all.yml
minikube addon enable ingress     # if you install k3 please skip this
kubectl apply -f ingress.yml
kubectl get pod -n ingress-nginx
kubectl get pod -A | grep nginx --> check the container is running
kubectl get ingress --> copy the address
sudo nano /etc/hosts --> paste it and name it foo.bar.com (domain mapping in local)
curl -L http://foo.bar.com or Open in Browser
```
## To uninstall

```
cd shellscripts

execute the script you want  eg: sh uninstall_blah.sh
```