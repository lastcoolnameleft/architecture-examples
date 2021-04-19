# Ingress Examples

These examples assume that you have an existing Ingress Controller installed.

Here's the steps, inspired from https://docs.microsoft.com/en-us/azure/aks/ingress-basic

```
kubectl create namespace ingress-basic
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
```

NOTE: This uses 1 replica instead of 2 to make it easier to debug
NOTE: To enable more logs: https://kubernetes.github.io/ingress-nginx/troubleshooting/#debug-logging
