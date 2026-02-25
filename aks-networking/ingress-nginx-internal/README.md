# Ingress — NGINX Internal

> NGINX Ingress Controller with internal (private) Azure LoadBalancer and sample service deployments.

## Contents

| File | Description |
|------|-------------|
| [helm-values-nginx-ingress-internal.yaml](helm-values-nginx-ingress-internal.yaml) | Helm values to deploy NGINX Ingress with an internal LoadBalancer |
| [kuard-ingress.yaml](kuard-ingress.yaml) | Kuard ingress manifest |
| [podinfo-ingress.md](podinfo-ingress.md) | Quick Helm install for podinfo with ingress |
| [podinfo-multiple-ns.md](podinfo-multiple-ns.md) | Deploy podinfo across multiple namespaces with ingress rules |

## When to Use This

- You need an ingress controller that is not exposed to the internet
- You're using APIM, Front Door, or Application Gateway in front of the ingress
- You're in an enterprise environment where all traffic must stay on the Azure backbone
