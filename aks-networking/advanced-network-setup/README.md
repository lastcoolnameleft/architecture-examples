# Advanced Network Setup

> AKS cluster creation scripts with Azure CNI (advanced networking) — using both Azure CLI and ARM templates.

## Contents

| File | Description |
|------|-------------|
| [create-aks-adv-network.sh](create-aks-adv-network.sh) | Create AKS cluster with advanced networking using Azure CLI |
| [create-aks-adv-network-arm.sh](create-aks-adv-network-arm.sh) | Create AKS cluster with advanced networking using ARM templates |

## When to Use This

- You need AKS pods to have VNet-routable IPs (Azure CNI)
- You're integrating AKS into an existing VNet with specific subnet requirements
- You need network policies or direct pod-to-VM connectivity
