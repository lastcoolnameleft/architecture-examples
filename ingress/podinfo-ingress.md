#  The easiest way is to install the Helm charts for each

```shell
INGRESS_IP=$(kgsvc -n ingress-basic nginx-ingress-ingress-nginx-controller -o json | jq '.status.loadBalancer.ingress[0].ip' -r)
UI_MESSAGE=podinfo-ingress

helm upgrade --install --wait podinfo podinfo/podinfo \
    --set ui.message=$UI_MESSAGE \
    --set ingress.enabled=true \
    --set "ingress.hosts[0]=podinfo.$INGRESS_IP.nip.io" \
    --set ingress.path='/'
```
