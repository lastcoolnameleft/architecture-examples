# Azure Voting App - Container Offer

This directory contains an **Azure Marketplace Container Offer** (Kubernetes Application) based on the [Azure Voting App Redis](https://github.com/Azure-Samples/azure-voting-app-redis) sample.

A Container Offer installs a Helm chart via the `Microsoft.KubernetesConfiguration/extensions` API onto an **existing** AKS cluster. The customer selects their cluster during the Marketplace purchase flow.

## Directory Structure

```
container-offer/
├── app/                          # Application source code
│   ├── Dockerfile                # Container image build
│   └── azure-vote/
│       ├── main.py               # Flask application
│       ├── config_file.cfg       # Default config
│       ├── requirements.txt      # Python dependencies
│       ├── static/default.css    # Stylesheet
│       └── templates/index.html  # HTML template
├── helm-chart/
│   └── azure-vote/               # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           └── secret.yaml
├── arm-template/
│   ├── mainTemplate.json         # ARM template (extension only)
│   └── createUiDefinition.json   # Marketplace UI definition
└── manifest.yaml                 # CNAB packaging instructions
```

## How It Works

1. **Application** – A Python Flask app that provides a simple two-option voting interface backed by Redis.
2. **Helm Chart** – Packages the app for Kubernetes. Supports both in-cluster Redis and external Redis (Azure Cache for Redis) via `values.yaml`.
3. **ARM Template** – Contains *only* the `Microsoft.KubernetesConfiguration/extensions` resource. This is what Marketplace deploys onto the customer's AKS cluster.
4. **CNAB Bundle** – The Helm chart and container image are packaged into a CNAB bundle and pushed to an ACR for Marketplace publishing.

## Before You Start: Replace Placeholders

Several files contain `<YOUR_...>` placeholders that must be replaced with your own values before packaging or deploying. See the [root README](../README.md#before-you-start-replace-placeholders) for the full placeholder reference table.

Files in this directory that need updates:

| File | Placeholders |
|---|---|
| `arm-template/mainTemplate.json` | `<YOUR_PUBLISHER_ID>`, `<YOUR_OFFER_ID>`, `<YOUR_PLAN_ID>`, `<YOUR_EXTENSION_NAME>` |
| `manifest.yaml` | `<YOUR_BUNDLE_NAME>`, `<YOUR_PUBLISHER_DISPLAY_NAME>`, `<YOUR_ACR_NAME>` |
| `helm-chart/azure-vote/values.yaml` | `<YOUR_ACR_NAME>` |
| `porter.yaml` | `<YOUR_BUNDLE_NAME>`, `<YOUR_ACR_NAME>` |
| `test-install-extension/mainTemplate.json` | `<YOUR_PUBLISHER_ID>`, `<YOUR_OFFER_ID>`, `<YOUR_PLAN_ID>`, `<YOUR_EXTENSION_NAME>` |

## Publishing Steps

### 1. Build and Push the Container Image

```bash
ACR_NAME="<your-acr>"
IMAGE_TAG="1.0.0"

# Build using ACR Tasks (no local Docker required)
az acr build -r $ACR_NAME -t azure-vote-front:${IMAGE_TAG} ./app/
```

### 2. Update Helm Chart Image Reference

Edit `helm-chart/azure-vote/values.yaml` and set `image.repository` to your ACR image path.

### 3. Grant Microsoft Access to Your ACR

The CPA tool copies the CNAB to a Microsoft-owned registry. Grant the Marketplace ingestion service principal pull access:

```bash
# Create the service principal if it doesn't exist
az ad sp show --id 32597670-3e15-4def-8851-614ff48c1efa || \
  az ad sp create --id 32597670-3e15-4def-8851-614ff48c1efa

# Grant ACR pull access
SP_ID=$(az ad sp show --id 32597670-3e15-4def-8851-614ff48c1efa --query id -o tsv)
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)
az role assignment create --assignee $SP_ID --scope $ACR_ID --role acrpull

# Register the PartnerCenterIngestion resource provider
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az provider register --namespace Microsoft.PartnerCenterIngestion \
  --subscription $SUBSCRIPTION_ID --wait
```

### 4. Package and Publish the CNAB Bundle Using CPA

The **Container Package App (CPA)** tool validates artifacts, builds the CNAB, and pushes it to your ACR. Run it via Docker:

```bash
# Pull the CPA tool
docker pull mcr.microsoft.com/container-package-app:latest

# Run it, mounting the container-offer/ directory
docker run -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/data \
  --entrypoint "/bin/bash" \
  mcr.microsoft.com/container-package-app:latest
```

Inside the container:

```bash
export REGISTRY_NAME=<your-acr-name>
az login
az acr login -n $REGISTRY_NAME
cd /data/container-offer

# Validate all artifacts
cpa verify

# Build and push the CNAB bundle to ACR
cpa buildbundle
```

> Use `cpa buildbundle --force` to overwrite an existing tag. If this CNAB is already attached to a Partner Center offer, increment the version in `manifest.yaml` instead.

### 5. Update ARM Template

Edit `arm-template/mainTemplate.json` and update the `variables` section to match your published offer:

```json
"variables": {
    "plan-name": "<your-plan-id>",
    "plan-publisher": "<your-publisher-id>",
    "plan-offerID": "<your-offer-id>",
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
| `clusterExtensionTypeName` | Partner Center > Plan > Technical Configuration > **Cluster Extension Type**, or discover via `az k8s-extension extension-types list-by-cluster` |

Also update the `configurationSettings` in the extension resource if your application uses different Helm values than the sample voting app.

### 6. Create the Offer in Partner Center

1. Go to [Partner Center](https://partner.microsoft.com/dashboard)
2. Create a new **Azure Container** offer
3. Under **Technical configuration**, reference the CNAB tag pushed to your ACR
4. Upload `mainTemplate.json` and `createUiDefinition.json`
5. Configure pricing and publish



## References

- [Azure Container Offer docs](https://learn.microsoft.com/azure/marketplace/azure-container-offer-setup)
- [Kubernetes Application technical assets](https://learn.microsoft.com/azure/marketplace/azure-container-technical-assets-kubernetes)
- [CNAB Bundle creation](https://learn.microsoft.com/azure/marketplace/azure-container-technical-assets-kubernetes#create-and-test-the-cnab-bundle)
