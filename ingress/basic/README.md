# Ingress Architecture

This Architecture Diagram is based upon the [AKS Basic Ingress Controller](https://docs.microsoft.com/en-us/azure/aks/ingress-basic#create-an-ingress-controller)

## Intent

This goal of this document is to provide a reference architecture using the following:

* AKS
* Basic Ingress Controller using NGINX 
* Two applications (Using the same container image, but different settings)
* Two Ingress rules to route to each app based on the path

## Architecture

Overall Ingress Architecture

![Ingress](ingress.svg)

Azure Network Architecture

![Network](networking.svg)

If you are interested in seeing more detail, view the [Ingress Drawio file](ingress.draw.io) using the [VSCode Draw.io extension](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio).

## Implementation

Deploy NGINX Ingress Controller

```
# Create a namespace for your ingress resources
$ kubectl create namespace ingress-basic

# Add the ingress-nginx repository
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Use Helm to deploy an NGINX ingress controller
$ helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
    --set controller.replicaCount=1 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux
```

Deploy the apps

```
$ kubectl create namespace hello-world
$ kubectl apply -f aks-helloworld-one.yaml
$ kubectl apply -f aks-helloworld-two.yaml
```

Deploy the Ingress

```
$ kubectl apply -f hello-world-ingress.yaml
```

Validate

```
$ curl -s $INGRESS_IP/hello-world-one | grep logo
        <div id="logo">Welcome to Azure Kubernetes Service (AKS)</div>
        <img src="/static/acs.png" als="acs logo">

$ curl -s $INGRESS_IP/hello-world-two | grep logo
        <div id="logo">AKS Ingress Demo</div>
        <img src="/static/acs.png" als="acs logo">
```