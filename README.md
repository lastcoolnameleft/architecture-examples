# Cloud Architecture Examples

> Reusable architecture patterns, walkthroughs, and Kubernetes manifests from real-world Azure engagements. Designed to share with partners and customers for reuse across engagements.

## Start Here

| If you need... | Go to |
|----------------|-------|
| Quick kubectl commands | [aks-fundamentals/](aks-fundamentals/) |
| Ingress / networking setup | [aks-networking/](aks-networking/) |
| Private connectivity between services | [aks-private-link/](aks-private-link/) |
| A reference architecture diagram | [ip-cosell/](ip-cosell/), [container-offer/](container-offer/), [managed-application/](managed-application/) |

---

## Architecture Patterns

| Directory | Description |
|-----------|-------------|
| [aks-private-link/](aks-private-link/) | Private Link Service + Private Endpoint — ingress-based and service-based approaches |
| [aks-multi-tenant/](aks-multi-tenant/) | Multi-tenant deployment using namespaces, Helm, and Ingress |
| [aks-monitoring/](aks-monitoring/) | Azure Managed Grafana + Prometheus + Loki with Private Endpoints |
| [aks-on-prem-data/](aks-on-prem-data/) | AKS workloads accessing on-premises data sources |
| [cluster-api-capz/](cluster-api-capz/) | Cluster API for Azure (CAPZ) overview |
| [ip-cosell/](ip-cosell/) | Reference architecture diagram for Azure IP Co-Sell submissions |
| [container-offer/](container-offer/) | Architecture for container-based Azure Marketplace offers |
| [managed-application/](managed-application/) | Architecture for Azure Managed Applications |
| [devops-gitops/](devops-gitops/) | On-premises GitLab → AKS GitOps pipeline architecture |

## Kubernetes Examples

| Directory | Description |
|-----------|-------------|
| [aks-fundamentals/](aks-fundamentals/) | AKS walkthrough + kubectl one-liners |
| [aks-networking/](aks-networking/) | Ingress (NGINX, Traefik, ModSecurity), Front Door, advanced networking |
| [aks-services/](aks-services/) | Service manifests: ClusterIP, LoadBalancer (public/internal), static IP |
| [aks-storage/](aks-storage/) | Persistent storage: Azure Files, Managed Disks, BlobFuse |
| [aks-iam-rbac/](aks-iam-rbac/) | Enterprise IAM posture: Entra ID, PIM, persona-based RBAC |
| [aks-apim/](aks-apim/) | API Management + private AKS + internal Ingress |
| [aks-backup-restore/](aks-backup-restore/) | Disaster recovery with Velero (Restic and Azure Disk Snapshots) |
| [troubleshooting/](troubleshooting/) | SSH to nodes, debug pods, RBAC utilities |

## Playground

The [playground/](playground/) directory is for prototyping architecture diagrams during customer engagements. It is **gitignored** — nothing in it gets checked in. Once a pattern is generic enough to share, move it to the appropriate top-level directory.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the template and workflow for adding new examples.
