# Ingress — ModSecurity WAF

> NGINX Ingress Controller with ModSecurity Web Application Firewall enabled.

## Contents

| File | Description |
|------|-------------|
| [kuard-ingress-modsecurity.yaml](kuard-ingress-modsecurity.yaml) | Ingress manifest with ModSecurity annotations enabled |

## When to Use This

- You need Layer 7 WAF protection at the ingress level
- You want OWASP Core Rule Set (CRS) protection without Azure Front Door or Application Gateway
- You're testing WAF rules before deploying to production
