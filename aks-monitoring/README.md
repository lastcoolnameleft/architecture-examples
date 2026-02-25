# AKS Monitoring

> Observability patterns for AKS: Azure Managed Grafana, Prometheus, and Loki.

## Contents

| Directory | Description |
|-----------|-------------|
| [amg-private-loki/](amg-private-loki/) | AKS + Azure Managed Grafana + Prometheus + Loki with Private Endpoints — full walkthrough with architecture diagram |

## When to Use This

- You need centralized monitoring for AKS with Grafana dashboards
- You want log aggregation with Loki running inside the cluster
- You need private connectivity between Grafana and AKS (no public endpoints)

## Related

- [AKS Private Link](../aks-private-link/) — Private Link patterns used in the AMG + Loki architecture
