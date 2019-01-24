#!/bin/bash

TENANT=$1
TEMPLATE_FILE=values/TEMPLATE.yaml
TENANT_FILE=values/$TENANT.yaml

if [[ -z "$TENANT" ]]; then
  echo "Usage: $0 <tenant>"
  echo "ERROR: Customer value not provided"
  exit 1
fi

echo "Creating tenant $TENANT"

function create_tenant_value_file() {
  echo "Creating the Helm value file: $TENANT_FILE from $TEMPLATE_FILE"

  cp $TEMPLATE_FILE $TENANT_FILE
  #echo sed -i '' "s/TENANT/$TENANT/g" $TENANT_FILE
  sed -i '' "s/TENANT/$TENANT/g" $TENANT_FILE
}

function deploy_helm() {
  echo "Deploying helm chart: "
  echo helm install -f $TENANT_FILE multi-tenant-kuard --name $TENANT --namespace $TENANT
  helm install -f $TENANT_FILE multi-tenant-kuard --name $TENANT --namespace $TENANT
}

create_tenant_value_file
deploy_helm
