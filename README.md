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
sudo ufw allow 6443/tcp #apiserver
sudo ufw allow from 10.42.0.0/16 to any #pods
sudo ufw allow from 10.43.0.0/16 to any #services
eval $(minikube docker-env)       # if you install k3 please skip this
docker pull dockerrexxzz/dj:latest
kubectl apply -f all.yml
kubectl port-forward svc/sample-service 8000:8000
<!-- minikube addon enable ingress     # if you install k3 please skip this
sudo nano /etc/hosts --> 127.0.0.1 sample-ing.local   (domain mapping in local)
curl -L http://sample-ing.local  or Open in Browser -->
```
## To uninstall

```
cd shellscripts

execute the script you want  eg: sh uninstall_blah.sh
```