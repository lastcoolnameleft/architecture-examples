# Azure Voting App - Managed Application Offer

This directory contains an **Azure Managed Application** offer that deploys the complete infrastructure for the Azure Voting App, including:

- **AKS cluster** – Kubernetes cluster with Azure CNI networking
- **Azure Managed Redis** – Managed Redis with TLS enforcement, private endpoint only (no public access)
- **Virtual Network** – VNet with AKS subnet and private endpoint subnet
- **Private Endpoint & DNS** – Private link for Redis with automatic DNS registration
- **Managed Identity** – User-assigned identity for AKS with Network Contributor role
- **Container Offer Extension** – Installs the voting app Helm chart on AKS

## Directory Structure

```
managed-app-offer/
├── arm-template/
│   ├── mainTemplate.json         # Full infrastructure ARM template
│   ├── createUiDefinition.json   # Marketplace UI wizard
│   └── viewDefinition.json       # Managed app dashboard views
└── scripts/
    ├── deploy.sh                 # Test deployment script
    ├── cleanup.sh                # Resource cleanup script
    ├── parameters.json           # Test parameters
    └── infra-only-template.json  # Template without extension (for testing)
```

## Before You Start: Replace Placeholders

The `arm-template/mainTemplate.json` contains `<YOUR_...>` placeholders in the `variables` section that must be replaced with your published Container Offer values before deploying with `--with-extension`. See the [root README](../README.md#before-you-start-replace-placeholders) for the full placeholder reference table.

| Placeholder | Where to find it |
|---|---|
| `<YOUR_PUBLISHER_ID>` | Partner Center > Account settings > **Publisher ID** |
| `<YOUR_OFFER_ID>` | Partner Center > Your offer > **Offer ID** |
| `<YOUR_PLAN_ID>` | Partner Center > Your offer > Plan overview > **Plan ID** |
| `<YOUR_EXTENSION_NAME>` | Partner Center > Plan > Technical Configuration > **Cluster Extension Type** |

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Managed Resource Group                                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Virtual Network (10.0.0.0/16)                         │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  AKS Subnet (10.0.0.0/22)                        │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │  AKS Cluster                               │  │  │  │
│  │  │  │  ┌────────────┐ ┌─────────────┐            │  │  │  │
│  │  │  │  │ vote-front │ │ Extension   │            │  │  │  │
│  │  │  │  │ (Pod)      │ │ (Helm)      │            │  │  │  │
│  │  │  │  └─────┬──────┘ └─────────────┘            │  │  │  │
│  │  │  │        │                                   │  │  │  │
│  │  │  └────────│───────────────────────────────────┘  │  │  │
│  │  └───────────│──────────────────────────────────────┘  │  │
│  │              │ TLS (port 10000)                        │  │
│  │  ┌───────────│──────────────────────────────────────┐  │  │
│  │  │  PE Subnet (10.0.4.0/24)                         │  │  │
│  │  │  ┌────────▼─────────────────────────────────┐    │  │  │
│  │  │  │  Private Endpoint (pe-redis-*)           │    │  │  │
│  │  │  └────────┬─────────────────────────────────┘    │  │  │
│  │  └───────────│──────────────────────────────────────┘  │  │
│  └──────────────│─────────────────────────────────────────┘  │
│                 │ Private Link                               │
│  ┌──────────────▼─────────────────────────────────────────┐  │
│  │  Azure Managed Redis (TLS-only, public access off)     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Private DNS Zone (privatelink.redis.azure.net)        │  │
│  │  → Linked to VNet, auto-registers PE private IP        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  User-Assigned Managed Identity                        │  │
│  │  (Network Contributor on AKS subnet)                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Testing the Deployment

### Prerequisites

- Azure CLI (`az`) installed and logged in
- An Azure subscription with permissions to create resources

### Deploy Infrastructure

```bash
cd managed-app-offer/scripts

# Deploy with default settings (infrastructure only, no extension)
./deploy.sh

# Deploy with custom resource group and location
./deploy.sh -g my-test-rg -l westus2

# Deploy with the container offer extension (requires published offer)
./deploy.sh --with-extension
```

The default deployment creates:
- Resource group: `rg-voting-app-test`  
- Region: `centralus`
- AKS: 3x Standard_D4ds_v5 nodes
- Redis: Balanced_B0 (private endpoint, no public access)
- Private DNS zone: `privatelink.redis.azure.net`

### After Deployment

```bash
# Get AKS credentials
az aks get-credentials -g rg-voting-app-test -n aks-voting-test

# Verify the cluster is running
kubectl get nodes

# If using --with-extension, check the extension status
az k8s-extension show \
  --cluster-name aks-voting-test \
  --resource-group rg-voting-app-test \
  --cluster-type managedClusters \
  --name azure-vote

# Get the voting app external IP
kubectl get svc -l app=azure-vote-front
```

### Verify Private Endpoint Connectivity

After deployment, verify that Redis is accessible only via private endpoint:

```bash
# Confirm Redis public access is disabled
az redisenterprise show -n redis-voting-test -g rg-voting-app-test --query publicNetworkAccess -o tsv
# Expected: Disabled

# List private endpoints
az network private-endpoint list -g rg-voting-app-test -o table

# Check the private DNS A record
az network private-dns record-set a list \
  -g rg-voting-app-test \
  -z privatelink.redis.azure.net -o table

# Capture the managed Redis host name
REDIS_HOST=$(az redisenterprise show -n redis-voting-test -g rg-voting-app-test --query hostName -o tsv)

# Verify DNS resolution from inside AKS
kubectl run dns-test --rm -it --image=busybox --restart=Never -- \
  nslookup $REDIS_HOST

# Test Redis connectivity from a pod
REDIS_KEY=$(az redisenterprise database list-keys --cluster-name redis-voting-test -g rg-voting-app-test -n default --query primaryKey -o tsv)
kubectl run redis-test --rm -it --image=redis:7 --restart=Never -- \
  redis-cli -h $REDIS_HOST -p 10000 --tls -a "$REDIS_KEY" PING
# Expected: PONG
```

### Deploy the Voting App Manually (Without Extension)

If you deployed infrastructure-only, you can install the Helm chart directly:

```bash
# Get Redis credentials
REDIS_HOST=$(az redisenterprise show -n redis-voting-test -g rg-voting-app-test --query hostName -o tsv)
REDIS_KEY=$(az redisenterprise database list-keys --cluster-name redis-voting-test -g rg-voting-app-test -n default --query primaryKey -o tsv)

# Install via Helm
helm install azure-vote ../container-offer/helm-chart/azure-vote/ \
  --set redis.host=$REDIS_HOST \
  --set redis.port=10000 \
  --set redis.ssl=true \
  --set redis.password=$REDIS_KEY
```

### Cleanup

```bash
# Interactive cleanup (with confirmation)
./cleanup.sh

# Auto-confirm cleanup
./cleanup.sh -y

# Cleanup a specific resource group
./cleanup.sh -g my-test-rg -y
```

## Publishing to Azure Marketplace

### 1. Prepare the Package

Package the ARM template files into a ZIP for Partner Center:

```bash
cd arm-template
zip managed-app-package.zip mainTemplate.json createUiDefinition.json viewDefinition.json
```

### 2. Update Template Variables

Edit `mainTemplate.json` and update the `variables` section to match your published Container Offer:

```json
"variables": {
    ...
    "plan-publisher": "<your-publisher-id>",
    "plan-offerID": "<your-offer-id>",
    "plan-name": "<your-plan-id>",
    "releaseTrain": "stable",
    "clusterExtensionTypeName": "<your-publisher-id>.<your-extension-name>"
}
```

| Variable | Where to find it |
|---|---|
| `plan-name` | Partner Center > Your offer > Plan overview > **Plan ID** |
| `plan-publisher` | Partner Center > Account settings > **Publisher ID** |
| `plan-offerID` | Partner Center > Your offer > **Offer ID** |
| `releaseTrain` | Typically `stable`; use `preview` if still in testing |
| `clusterExtensionTypeName` | Partner Center > Plan > Technical Configuration > **Cluster Extension Type** |

Also review the `configurationSettings` in the `Microsoft.KubernetesConfiguration/extensions` resource. The current template passes voting app settings (`vote.title`, `vote.value1`, `vote.value2`) and Redis connection settings. Update these to match the Helm values your application requires.

If you modified the infrastructure (e.g. different Redis SKU, networking ranges, node pools), update `mainTemplate.json` to match and also update `createUiDefinition.json` if you added/removed/changed any parameters.

### 3. Create the Offer

1. Go to [Partner Center](https://partner.microsoft.com/dashboard)
2. Create a new **Azure Application** offer (Managed Application type)
3. Upload the `managed-app-package.zip`
4. Configure authorization policies, pricing, and legal terms
5. Publish

## Cost Estimate

| Resource | SKU | Estimated Monthly Cost |
|---|---|---|
| AKS (3 nodes) | Standard_D4ds_v5 | ~$460 |
| Azure Managed Redis | Balanced_B0 | Varies by region |
| Private Endpoint | – | ~$7 |
| Private DNS Zone | – | ~$0.50 |
| VNet | Standard | Free |
| Managed Identity | – | Free |
| **Total** | | **~$484/month** |

*Costs vary by region and may change. Use the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for current estimates.*

## References

- [Azure Managed Application docs](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/overview)
- [Create UI Definition](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/create-uidefinition-overview)
- [View Definition](https://learn.microsoft.com/azure/azure-resource-manager/managed-applications/concepts-view-definition)
