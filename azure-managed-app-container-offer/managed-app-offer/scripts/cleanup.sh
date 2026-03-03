#!/usr/bin/env bash
#
# cleanup.sh - Delete the test resource group and all resources
#
# Usage:
#   ./cleanup.sh [OPTIONS]
#
# Options:
#   -g, --resource-group    Resource group name (default: rg-voting-app-test)
#   -y, --yes               Skip confirmation prompt
#   -h, --help              Show this help message
#
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-voting-app-test}"
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -y|--yes) SKIP_CONFIRM=true; shift ;;
    -h|--help)
      head -14 "$0" | tail -11
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "============================================="
echo "  Azure Voting App - Cleanup"
echo "============================================="
echo ""
echo "  Resource Group: ${RESOURCE_GROUP}"
echo ""

# Check if resource group exists
if ! az group show --name "${RESOURCE_GROUP}" &>/dev/null; then
  echo "Resource group '${RESOURCE_GROUP}' does not exist. Nothing to clean up."
  exit 0
fi

# List resources
echo "Resources in '${RESOURCE_GROUP}':"
az resource list --resource-group "${RESOURCE_GROUP}" --output table
echo ""

# Confirm deletion
if [ "${SKIP_CONFIRM}" = false ]; then
  read -p "Are you sure you want to delete resource group '${RESOURCE_GROUP}' and all its resources? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

echo ">> Deleting resource group '${RESOURCE_GROUP}'... (this may take several minutes)"
az group delete \
  --name "${RESOURCE_GROUP}" \
  --yes

echo ""
echo ">> Resource group '${RESOURCE_GROUP}' and all its resources have been deleted."
echo ""
