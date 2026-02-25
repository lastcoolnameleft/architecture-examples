# AKS Services

> Kubernetes Service manifests showing different exposure patterns: ClusterIP, LoadBalancer (public/internal), and static IPs.

## Contents

| File | Description |
|------|-------------|
| [kuard-service-cluster-ip.yaml](kuard-service-cluster-ip.yaml) | ClusterIP service — internal-only, reachable within the cluster |
| [kuard-service-lb.yaml](kuard-service-lb.yaml) | Public LoadBalancer service — creates an Azure public IP |
| [kuard-service-lb-internal.yaml](kuard-service-lb-internal.yaml) | Internal LoadBalancer — Azure internal IP, no public exposure |
| [podinfo-external-lb.yaml](podinfo-external-lb.yaml) | Podinfo with public LoadBalancer |
| [podinfo-internal-lb-static-ip.yaml](podinfo-internal-lb-static-ip.yaml) | Internal LoadBalancer with a pre-allocated static IP |
| [tcp-echo.yaml](tcp-echo.yaml) | TCP echo service for network testing |
| [kuard-deployment.yaml](kuard-deployment.yaml) | Basic kuard Deployment manifest |
| [sleep.yaml](sleep.yaml) | Sleep container for debugging / exec-ing into |

## When to Use This

- You need a quick Service manifest to test connectivity
- You're deciding between ClusterIP, public LB, or internal LB
- You need a static IP for an internal service
- You need a baseline deployment to test against

## Quick Reference

```
ClusterIP       → cluster-internal only, use with Ingress or port-forward
LoadBalancer    → creates Azure LB with public IP
Internal LB     → annotation: service.beta.kubernetes.io/azure-load-balancer-internal: "true"
Static IP       → annotation: service.beta.kubernetes.io/azure-load-balancer-ipv4 + loadBalancerIP
```
