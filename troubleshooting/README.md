# Troubleshooting

> Debugging tools, diagnostic pods, and RBAC utilities for AKS.

## Contents

| File | Description |
|------|-------------|
| [ssh-to-node.sh](ssh-to-node.sh) | SSH into AKS nodes via a privileged jump pod + `kubectl port-forward` |
| [ubuntu-two-pods-two-nodes.yaml](ubuntu-two-pods-two-nodes.yaml) | Two Ubuntu debug pods scheduled on different nodes — useful for inter-node networking tests |
| [cluster-admin-role.yaml](cluster-admin-role.yaml) | ClusterRoleBinding for cluster-admin access |
| [helm.yaml](helm.yaml) | Tiller RBAC for Helm v2 (legacy — Helm 3 does not need Tiller) |

## When to Use This

- You need to SSH into an AKS node for low-level debugging
- You need to test pod-to-pod connectivity across nodes
- You need a quick cluster-admin binding for troubleshooting

## Quick SSH to Node

```bash
# Find the node name
kubectl get nodes

# Run the SSH script
./ssh-to-node.sh <node-name>
```
