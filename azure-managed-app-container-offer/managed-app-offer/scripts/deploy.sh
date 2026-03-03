#!/usr/bin/env bash
#
# deploy.sh - Deploy the Managed App infrastructure for testing
#
# This script deploys AKS, Azure Managed Redis, VNet, managed identity,
# and the voting app extension. It skips the container offer extension
# by default since the extension type must be published first. Use
# --with-extension to include it (requires a published container offer).
#
# Usage:
#   ./deploy.sh [OPTIONS]
#
# Options:
#   -g, --resource-group    Resource group name (default: rg-voting-app-test)
#   -l, --location          Azure region (default: eastus)
#   -p, --parameters        Parameters file path (default: ./parameters.json)
#   -n, --deployment-name   Deployment name (default: voting-app-<timestamp>)
#       --with-extension    Include the container offer extension resource
#   -h, --help              Show this help message
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-voting-app-test}"
LOCATION="${LOCATION:-centralus}"
PARAMETERS_FILE="${PARAMETERS_FILE:-${SCRIPT_DIR}/parameters.json}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-voting-app-$(date +%Y%m%d%H%M%S)}"
AKS_NAME="${AKS_NAME:-}"
WITH_EXTENSION=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -l|--location) LOCATION="$2"; shift 2 ;;
    -p|--parameters) PARAMETERS_FILE="$2"; shift 2 ;;
    -n|--deployment-name) DEPLOYMENT_NAME="$2"; shift 2 ;;
    --with-extension) WITH_EXTENSION=true; shift ;;
    -h|--help)
      head -20 "$0" | tail -17
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TEMPLATE_FILE="${SCRIPT_DIR}/../arm-template/mainTemplate.json"
INFRA_TEMPLATE_FILE="${SCRIPT_DIR}/infra-only-template.json"

echo "============================================="
echo "  Azure Voting App - Infrastructure Deploy"
echo "============================================="
echo ""
echo "  Resource Group:   ${RESOURCE_GROUP}"
echo "  Location:         ${LOCATION}"
echo "  Deployment:       ${DEPLOYMENT_NAME}"
echo "  With Extension:   ${WITH_EXTENSION}"
echo ""

# Check Azure CLI is logged in
if ! az account show &>/dev/null; then
  echo "ERROR: Not logged in to Azure CLI. Run 'az login' first."
  exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "  Subscription:     ${SUBSCRIPTION}"
echo ""

# Create resource group
echo ">> Creating resource group '${RESOURCE_GROUP}' in '${LOCATION}'..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output none

# Choose the template
if [ "${WITH_EXTENSION}" = true ]; then
  DEPLOY_TEMPLATE="${TEMPLATE_FILE}"
  echo ">> Deploying full template (with container extension)..."
else
  DEPLOY_TEMPLATE="${INFRA_TEMPLATE_FILE}"
  echo ">> Deploying infrastructure-only template (without container extension)..."
fi

# Deploy
echo ">> Starting deployment '${DEPLOYMENT_NAME}'..."
echo "   This will take approximately 10-20 minutes..."
echo ""

# Build parameter arguments
PARAM_ARGS=("@${PARAMETERS_FILE}")
if [[ -n "${AKS_NAME}" ]]; then
  PARAM_ARGS+=("clusterName=${AKS_NAME}")
fi

az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --template-file "${DEPLOY_TEMPLATE}" \
  --parameters "${PARAM_ARGS[@]}" \
  --output table

echo ""
echo ">> Deployment complete!"
echo ""

# Get outputs
AKS_NAME=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.aksClusterName.value" -o tsv 2>/dev/null || echo "${AKS_NAME}")

AKS_FQDN=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.aksClusterFqdn.value" -o tsv 2>/dev/null || echo "N/A")

REDIS_HOST=$(az deployment group show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${DEPLOYMENT_NAME}" \
  --query "properties.outputs.redisHostName.value" -o tsv 2>/dev/null || echo "N/A")

echo "============================================="
echo "  Deployment Outputs"
echo "============================================="
echo "  AKS Cluster:    ${AKS_NAME}"
echo "  AKS FQDN:       ${AKS_FQDN}"
echo "  Redis Host:     ${REDIS_HOST}"
echo ""
echo "  To get AKS credentials:"
echo "    az aks get-credentials -g ${RESOURCE_GROUP} -n ${AKS_NAME}"
echo ""
echo "  To view deployed resources:"
echo "    az resource list -g ${RESOURCE_GROUP} -o table"
echo ""

# Export for downstream use
export AKS_NAME RESOURCE_GROUP REDIS_HOST AKS_FQDN
