# AKS with On-Premises Data

> Architecture pattern for AKS workloads that need to access data sources on-premises.

## Architecture Diagram

Open [aks-on-prem-data.drawio](aks-on-prem-data.drawio) in [draw.io](https://app.diagrams.net/) to view and edit.

## When to Use This

- Your AKS workloads need to query databases or APIs that remain on-premises
- You're in a hybrid cloud migration where not all data has moved to Azure yet
- You need secure connectivity between AKS and on-prem networks (ExpressRoute, VPN Gateway)

## Related

- [AKS Private Link](../aks-private-link/) — Private connectivity patterns between Azure resources
- [AKS Networking](../aks-networking/) — Ingress and advanced networking setup
