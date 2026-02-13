# AKS IAM Posture - Terraform Configuration

This Terraform configuration deploys an AKS cluster with enterprise-grade IAM posture.

## Features

- **Entra ID Integration**: Managed AAD with optional Azure RBAC for Kubernetes
- **No Local Accounts**: Local Kubernetes accounts disabled, forcing Entra ID auth
- **Comprehensive Audit Logging**: All API server and audit logs sent to Log Analytics
- **Security Hardening**: Defender, Azure Policy, workload identity, image cleaner
- **High Availability**: Multi-zone node pools with autoscaling

## Files

| File | Description |
|------|-------------|
| `main.tf` | Core AKS cluster and node pool resources |
| `variables.tf` | Input variable definitions |
| `outputs.tf` | Output values (cluster ID, FQDN, identities, etc.) |
| `versions.tf` | Terraform and provider version constraints |
| `terraform.tfvars` | Variable values (customize for your environment) |

## Usage

1. **Initialize Terraform**:
   ```bash
   cd infra/terraform
   terraform init
   ```

2. **Review the plan**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **Get kubectl credentials**:
   ```bash
   az aks get-credentials --resource-group iam-sandbox-rg --name iam-sandbox-aks
   ```

## Configuration

Edit `terraform.tfvars` to customize:

- `cluster_name` - AKS cluster name
- `cluster_admin_group_object_ids` - Entra ID group IDs for admin access
- `enable_azure_rbac` - Set `false` for K8s RBAC, `true` for Azure RBAC
- `enable_private_cluster` - Enable for production deployments

## Remote State (Recommended)

Uncomment and configure the backend block in `versions.tf` for Azure Storage backend:

```hcl
backend "azurerm" {
  resource_group_name  = "terraform-state-rg"
  storage_account_name = "tfstate<unique>"
  container_name       = "tfstate"
  key                  = "aks-iam.tfstate"
}
```

## Outputs

After deployment, use these outputs:

```bash
# Get cluster ID
terraform output aks_cluster_id

# Get kubeconfig (sensitive)
terraform output -raw kube_config > ~/.kube/config
```
