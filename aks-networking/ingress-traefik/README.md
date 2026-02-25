# Ingress — Traefik

> Traefik IngressRoute with middleware for IP whitelisting and header matching.

## Contents

| File | Description |
|------|-------------|
| [traefik-ip-whitelist-header-match.yaml](traefik-ip-whitelist-header-match.yaml) | Traefik middleware combining IP whitelist with header-based routing |

## When to Use This

- You're using Traefik as your ingress controller (instead of NGINX)
- You need to restrict access by source IP
- You need header-based routing or matching
