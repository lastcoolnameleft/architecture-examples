# AKS Private Link

> Expose AKS services to other VNets or subscriptions via Azure Private Link Service and Private Endpoint.

## Architecture

This pattern enables secure, private connectivity between an AKS-hosted service and consumers in separate VNets or subscriptions — without traversing the public internet.

## Contents

| Directory | Description |
|-----------|-------------|
| [ingress-based/](ingress-based/) | Private Link Service fronting an NGINX Ingress Controller — supports multiple backend services through a single Private Endpoint |
| [service-based/](service-based/) | Private Link Service fronting a Kubernetes Service directly (LoadBalancer) — simpler setup for single-service exposure |

## When to Use This

- ISV providing a service consumed by customers in their own Azure subscription
- Cross-VNet or cross-subscription private connectivity
- You need to avoid public IP exposure entirely
- Hub-spoke or multi-tenant network topologies

## Choosing Between Ingress-Based and Service-Based

| Approach | Use When |
|----------|----------|
| **Ingress-based** | Multiple services, path or host-based routing, TLS termination needed |
| **Service-based** | Single service, simple L4 TCP/UDP exposure, minimal overhead |

## Prerequisites

- AKS cluster with Azure CNI (for internal LoadBalancer IP allocation)
- Permissions to create Private Link Service and Private Endpoint resources
- Two VNets (can be in different subscriptions) if testing end-to-end
