# AKS Storage

> Persistent storage options for AKS: Azure Files, Managed Disks, and BlobFuse.

## Contents

| Directory / File | Description |
|------------------|-------------|
| [azure-files-pvc/](azure-files-pvc/) | Azure Files PVC with `ReadWriteMany` — multi-node mount with backend-writer + frontend-webserver pattern |
| [azure-managed-disk-pvc/](azure-managed-disk-pvc/) | Azure Managed Disk PVC with node migration demo |
| [blob-fuse.md](blob-fuse.md) | BlobFuse FlexVolume driver setup |

## When to Use This

- You need persistent storage that survives pod restarts
- You're choosing between Azure Files, Managed Disk, or BlobFuse

## Choosing a Storage Option

| Option | Access Mode | Use Case |
|--------|-------------|----------|
| **Azure Files** | ReadWriteMany | Multiple pods need to read/write the same files (e.g., shared config, CMS content) |
| **Managed Disk** | ReadWriteOnce | Single pod needs fast block storage (e.g., databases) |
| **BlobFuse** | ReadWriteOnce / ReadOnlyMany | Large-scale data access, cost-effective cold storage |

## Prerequisites

- AKS cluster running
- Azure storage account (for Azure Files and BlobFuse)
