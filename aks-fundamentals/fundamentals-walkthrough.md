# Create Cluster

```shell
RG=dol-demo
K8S_NAME=dol-demo

az group create -n $RG -l southcentralus
az aks create -g $RG -n $K8S_NAME --enable-vmss

az aks get-credentials -g $RG -n $K8S_NAME
cd ~/git/lastcoolnameleft/kubernetes-examples
```

# Namespaces

```shell
kubectl get ns
kubectl create ns k8s-demo
kubectl config set-context $K8S_NAME --namespace k8s-demo
# kubens k8s-demo
```

# Pod

# https://github.com/kubernetes-up-and-running/kuard

```
kubectl run kuard-pod --image=gcr.io/kuar-demo/kuard-amd64:1 --restart=Never --dry-run -o yaml > kuard-pod.yaml
kubectl run kuard-pod --image=gcr.io/kuar-demo/kuard-amd64:1 --restart=Never
kubectl get pods
kubectl expose pod kuard-pod --port=80 --target-port=8080 --type=LoadBalancer
kubectl get svc
curl <ip>
kubectl delete pod kuard
curl <ip>
kubectl get pods
```

# Deployment

```shell
kubectl run kuard-deployment --image=gcr.io/kuar-demo/kuard-amd64:1 --replicas=5 --dry-run -o yaml > kuard-deployment.yaml 
kubectl run kuard-deployment --image=gcr.io/kuar-demo/kuard-amd64:1 --replicas=5
kubectl get pods
kubectl get deployments
kubectl delete pod <pod>
kubectl get pods
```

# Services

```shell
kubectl expose deployment kuard-deployment --port=80 --target-port=8080 --type=LoadBalancer
curl <ip>
kubectl delete pod <kuard pod>
curl <ip>
```

# Helm

```shell
cat rbac/helm.yaml
kubectl apply -f rbac/helm.yaml
helm init --service-account tiller
helm version
helm install --name my-release --set minecraftServer.eula=true stable/minecraft
helm ls
kubectl get svc --namespace k8s-demo -w my-release-minecraft
```

# Ingress

```shell
helm install stable/nginx-ingress --name nginx-ingress --namespace ingress-controllers --set rbac.create=true
helm ls
kubectl apply -f ingress/kuard-ingress.yaml
kubectl get svc -n ingress-controllers -o json | jq '.items[0].status.loadBalancer.ingress[0].ip' -r
IP=$(kubectl get svc -n ingress-controllers -o json | jq '.items[0].status.loadBalancer.ingress[0].ip' -r)
curl $IP.xip.io
```
