#  The easiest way is to install the Helm charts for each

```shell
INGRESS_IP=$(kgsvc -n ingress-basic nginx-ingress-ingress-nginx-controller -o json | jq '.status.loadBalancer.ingress[0].ip' -r)

# Create 1st namespace + ingress + deployment
NAME=podinfo-1
kubectl create namespace $NAME
kubens $NAME

helm upgrade --install --wait $NAME podinfo/podinfo \
    --set ui.message=$NAME\
    --set ingress.enabled=true \
    --set "ingress.hosts[0]=$NAME.$INGRESS_IP.nip.io" \
    --set ingress.path='/'

# Now create 2nd namespace + ingress + deployment
NAME=podinfo-2
kubectl create namespace $NAME
kubens $NAME

helm upgrade --install --wait $NAME podinfo/podinfo \
    --set ui.message=$NAME\
    --set ingress.enabled=true \
    --set "ingress.hosts[0]=$NAME.$INGRESS_IP.nip.io" \
    --set ingress.path='/'
```

## Cleanup
```
kubectl delete namespace podinfo-1
kubectl delete namespace podinfo-2
```