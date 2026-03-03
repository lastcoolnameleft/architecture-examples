# Test Install Extension

Test template for installing the published Azure Marketplace container offer extension (`Microsoft.KubernetesConfiguration/extensions`) onto an existing AKS cluster.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- An existing AKS cluster (e.g. deployed via the [managed-app-offer infra-only-template](../../managed-app-offer/scripts/infra-only-template.json))
- An existing Redis instance (e.g. Azure Managed Redis deployed by the infra-only-template)
- The container offer must already be published to the Azure Marketplace

> **Note:** For the first deployment, consider deploying through the Azure Portal instead of the CLI. The Portal presents the Marketplace legal terms for acceptance, which is much easier to do in the UI. Once you've accepted the terms, subsequent deployments can be done via CLI.  

> Additionally, while deploying in the portal, you can view the ARM template and get some of the variables needed below.


## Configure for your offer

Before deploying, update the `variables` in `mainTemplate.json` to match your published offer and plan:

```json
"variables": {
    "plan-name": "<your-plan-name>",
    "plan-publisher": "<your-publisher-id>",
    "plan-offerID": "<your-offer-id>",
    "releaseTrain": "stable",
    "clusterExtensionTypeName": "<your-publisher-id>.<your-extension-name>"
}
```

| Variable | Where to find it |
|---|---|
| `plan-name` | Partner Center > Your offer > Plan overview > **Plan ID** |
| `plan-publisher` | Partner Center > Account settings > **Publisher ID** (also visible in the offer URL) |
| `plan-offerID` | Partner Center > Your offer > **Offer alias / Offer ID** |
| `releaseTrain` | Typically `stable`; matches the release train configured when publishing the CNAB bundle. If still in testing and the container offer has not been published, it will be `preview` |
| `clusterExtensionTypeName` | Format: `<publisher-id>.<extension-name>`. You can also discover it via: Partner Center > Your offer > Plan overview > Plan > Technical Configuration > **Cluster Extension Type** or `az k8s-extension extension-types list-by-cluster --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER_NAME --cluster-type managedClusters -o table` |

## Usage

### Set environment variables

```bash
# Required
export RESOURCE_GROUP="rg-voting-app-test"
export DEPLOYMENT_NAME="test-extension-$(date +%Y%m%d%H%M%S)"
export AKS_NAME=$(az aks list -g $RESOURCE_GROUP --query "[0].name" -o tsv)
export REDIS_NAME=$(az redisenterprise list -g $RESOURCE_GROUP --query "[0].name" -o tsv)


# Redis (required)
export REDIS_HOST=$(az redisenterprise show -n $REDIS_NAME -g $RESOURCE_GROUP --query hostName -o tsv)
export REDIS_PASSWORD=$(az redisenterprise database list-keys --cluster-name $REDIS_NAME -g $RESOURCE_GROUP --query primaryKey -o tsv)
export REDIS_PORT=$(az redisenterprise show -n $REDIS_NAME -g $RESOURCE_GROUP --query "databases[0].port" -o tsv)
export REDIS_SSL="true"
```

### Deploy the extension

```bash
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file mainTemplate.json \
  --parameters \
    clusterResourceName="$AKS_NAME" \
    redis_host="$REDIS_HOST" \
    redis_port="$REDIS_PORT" \
    redis_ssl="$REDIS_SSL" \
    redis_password="$REDIS_PASSWORD"
```

## Cleanup

Remove the extension from the cluster:

```bash
az k8s-extension delete \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$AKS_NAME" \
  --cluster-type managedClusters \
  --name azure-vote \
  --yes
```
