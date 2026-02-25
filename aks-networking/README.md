# AKS Networking

> Ingress controllers, Azure Front Door integration, advanced networking, and SSL configuration.

## Contents

| Directory / File | Description |
|------------------|-------------|
| [ingress-nginx-basic/](ingress-nginx-basic/) | Basic NGINX Ingress Controller setup with path-based routing for two apps |
| [ingress-nginx-internal/](ingress-nginx-internal/) | Internal (private) NGINX Ingress with Helm values, kuard, and podinfo examples |
| [ingress-modsecurity/](ingress-modsecurity/) | NGINX Ingress with ModSecurity WAF enabled |
| [ingress-traefik/](ingress-traefik/) | Traefik IngressRoute with IP whitelist and header matching middleware |
| [front-door-aks/](front-door-aks/) | Azure Front Door proxying traffic to AKS with multiple custom domains |
| [advanced-network-setup/](advanced-network-setup/) | AKS cluster creation scripts with Azure CNI (advanced networking) |
| [ingress-options.drawio](ingress-options.drawio) | Comparison diagram of AKS ingress options |
| [ssl-testing.md](ssl-testing.md) | SSL/TLS testing commands (curl, openssl) |

## When to Use This

- You need to expose services on AKS via HTTP/HTTPS
- You're choosing between NGINX and Traefik ingress controllers
- You're setting up Azure Front Door in front of AKS
- You need internal-only ingress (private LoadBalancer)
- You want WAF protection with ModSecurity

## Prerequisites

- AKS cluster running
- Helm 3 installed
- `kubectl` configured for the cluster
