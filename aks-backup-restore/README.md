# AKS Backup & Restore

> Disaster recovery patterns for AKS using Velero (formerly Heptio Ark).

> **Note:** These walkthroughs reference "Ark" which has been renamed to [Velero](https://velero.io/). The concepts and architecture remain the same.

## Contents

| File | Description |
|------|-------------|
| [velero-restic.md](velero-restic.md) | Backup and failover between AKS clusters in different regions using Velero + Restic (file-level backup) |
| [velero-snapshot.md](velero-snapshot.md) | Backup and failover using Velero + Azure Disk Snapshots (block-level backup) |

## When to Use This

- You need disaster recovery across Azure regions for AKS workloads
- You need to migrate workloads between AKS clusters
- You want to back up both Kubernetes resources and persistent volumes

## Choosing Between Restic and Snapshots

| Approach | Pros | Cons |
|----------|------|------|
| **Restic** | Works across cloud providers, file-level granularity | Slower for large volumes |
| **Azure Disk Snapshots** | Fast, native Azure integration | Azure-only, disk-level only |

## Prerequisites

- Two AKS clusters (source + destination) for DR testing
- Azure Blob Storage account for backup storage
- Velero CLI installed
