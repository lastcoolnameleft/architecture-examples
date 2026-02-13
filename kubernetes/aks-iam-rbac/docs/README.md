# =============================================================================
# AKS IAM Posture Implementation
# =============================================================================
# Comprehensive RBAC and IAM configuration for AKS clusters supporting a
# Nothing-Shared SaaS model with Entra ID integration and JIT elevation via PIM.
# =============================================================================

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Entra ID Group Naming Convention](#entra-id-group-naming-convention)
4. [Persona-to-Role Mapping](#persona-to-role-mapping)
5. [Role Definitions](#role-definitions)
6. [Deployment Guide](#deployment-guide)
7. [Multi-Cluster Rollout](#multi-cluster-rollout)
8. [JIT/PIM Configuration](#jitpim-configuration)
9. [Validation Checklist](#validation-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This implementation provides a comprehensive IAM posture for AKS clusters designed for:

- **Nothing-Shared SaaS Model**: Each customer/environment gets isolated AKS clusters
- **Persona-Based Access**: Roles aligned with operational responsibilities
- **Least Privilege**: Minimal permissions required for each persona
- **JIT Elevation**: All elevated access requires PIM activation
- **Audit Trail**: Complete logging of all access and actions

### Key Principles

1. **No individual user assignments** - All access is via Entra ID groups
2. **No wildcard permissions** - Explicit verbs and resources only
3. **Namespace isolation** - App teams cannot access kube-system
4. **Time-bound elevation** - Elevated access expires automatically
5. **Comprehensive auditing** - All actions logged to Log Analytics

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Entra ID (Azure AD)                          │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    PIM (Privileged Identity Management)       │   │
│  │  • Time-limited role activation                               │   │
│  │  • Approval workflows                                         │   │
│  │  • Audit trail                                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Entra ID Groups                            │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │   │
│  │  │ ClusterAdmin│ │ AppSupport  │ │ CommandCtr  │ ...         │   │
│  │  │  (L2/L3)    │ │   (L2)      │ │   (L1)      │             │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘             │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AKS Cluster                                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Azure RBAC for Kubernetes Authorization          │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   Kubernetes RBAC                            │    │
│  │  ┌─────────────────────┐  ┌─────────────────────┐           │    │
│  │  │   ClusterRoles      │  │      Roles          │           │    │
│  │  │  • cluster-readonly │  │  (per namespace)    │           │    │
│  │  │  • system-ns-op     │  │  • app-ns-operator  │           │    │
│  │  └─────────────────────┘  │  • l1-restricted    │           │    │
│  │                           └─────────────────────┘           │    │
│  │  ┌─────────────────────┐  ┌─────────────────────┐           │    │
│  │  │ ClusterRoleBindings │  │   RoleBindings      │           │    │
│  │  │  → Entra ID Groups  │  │   → Entra ID Groups │           │    │
│  │  └─────────────────────┘  └─────────────────────┘           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Log Analytics (Audit Logs)                       │   │
│  │  • kube-audit logs       • kube-apiserver logs               │   │
│  │  • guard logs (AAD auth) • cluster-autoscaler logs           │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Entra ID Group Naming Convention

### Convention Pattern

```
AKS-{ClusterName}-{Persona}-{Scope}-{ElevationType}
```

### Components

| Component | Description | Examples |
|-----------|-------------|----------|
| `ClusterName` | AKS cluster identifier | `acme-prod-eastus` |
| `Persona` | Role/team identifier | `InfraOps`, `AppSupport`, `CommandCentre` |
| `Scope` | Permission scope | `Cluster`, `Namespace`, `<NamespaceName>` |
| `ElevationType` | Access type | `Elevated` (JIT), `Viewer` (standing) |

### Recommended Groups per Cluster

| Group Name | Purpose | JIT Required |
|------------|---------|--------------|
| `AKS-{Cluster}-InfraOps-L2-Elevated` | Infra Operations (L2) cluster-wide | ✅ Yes |
| `AKS-{Cluster}-PlatformSRE-L3-Elevated` | Platform/SRE (L3) cluster-wide | ✅ Yes |
| `AKS-{Cluster}-AppSupport-L2-Elevated` | App Support (L2) namespace-scoped | ✅ Yes |
| `AKS-{Cluster}-CommandCentre-L1-Elevated` | Command Centre (L1) namespace-scoped | ✅ Yes |
| `AKS-{Cluster}-CloudDeployment-Elevated` | Cloud Deployment Engineer | ✅ Yes |
| `AKS-{Cluster}-ProjectDeploy-{Project}-Elevated` | Project-specific deployment | ✅ Yes |
| `AKS-{Cluster}-ClusterViewer` | Baseline cluster visibility | ❌ No |
| `AKS-{Cluster}-{Namespace}-Viewer` | Namespace read-only access | ❌ No |

---

## Persona-to-Role Mapping

### Cluster-Scoped Personas

| Persona | K8s Role | Azure RBAC Role | Access Scope | JIT |
|---------|----------|-----------------|--------------|-----|
| **Infra Operations (L2)** | `cluster-admin` + `system-namespace-operator` | Azure Kubernetes Service RBAC Cluster Admin | Cluster-wide, RWX | ✅ |
| **Platform Engineer/SRE (L3)** | `cluster-admin` + `system-namespace-operator` | Azure Kubernetes Service RBAC Cluster Admin | Cluster-wide, RWX | ✅ |

### Namespace-Scoped Personas

| Persona | K8s Role | Access Scope | Key Permissions | JIT |
|---------|----------|--------------|-----------------|-----|
| **App Support (L2)** | `app-namespace-operator` | App namespaces only | logs, exec, scale, restart | ✅ |
| **Command Centre (L1)** | `l1-restricted-operator` | App namespaces only | logs, restart (no exec) | ✅ |
| **Cloud Deployment Engineer** | `app-namespace-operator` | App namespaces only | deploy, troubleshoot | ✅ |
| **Project Deployment Engineer** | `project-deployment-temp` | Specific project namespace | time-limited deploy | ✅ |

### Permissions Matrix

| Permission | L3/L2 Cluster | App Support L2 | Command Centre L1 | Viewer |
|------------|---------------|----------------|-------------------|--------|
| View cluster resources | ✅ | ✅ | ✅ | ✅ |
| View namespace resources | ✅ | ✅ | ✅ | ✅ |
| Pod logs | ✅ | ✅ | ✅ | ✅ |
| Pod exec | ✅ | ✅ | ❌ | ❌ |
| Pod restart | ✅ | ✅ | ✅ | ❌ |
| Scale deployments | ✅ | ✅ | ❌ | ❌ |
| Modify deployments | ✅ | ✅ | ❌ | ❌ |
| Access secrets | ✅ | 👁️ Read-only | ❌ | ❌ |
| Access kube-system | ✅ | ❌ | ❌ | ❌ |
| RBAC management | ✅ | ❌ | ❌ | ❌ |

---

## Role Definitions

### Cluster-Scoped Roles

#### `cluster-readonly`
- **Purpose**: Baseline visibility across the cluster
- **Permissions**: Get/List/Watch on nodes, namespaces, storage classes, CRDs
- **JIT Required**: No (standing access)

#### `system-namespace-operator`
- **Purpose**: Full access to kube-system and system namespaces
- **Permissions**: Full CRUD on all resources in system namespaces
- **JIT Required**: Yes

### Namespace-Scoped Roles

#### `app-namespace-operator`
- **Purpose**: Full operational access within application namespaces
- **Permissions**:
  - Pods: get, list, watch, delete, exec, logs
  - Deployments/StatefulSets: full CRUD + scale
  - ConfigMaps: full CRUD
  - Secrets: read-only
  - Services/Ingress: full CRUD
- **JIT Required**: Yes
- **Excludes**: kube-system, kube-public, gatekeeper-system

#### `l1-restricted-operator`
- **Purpose**: Limited runbook-style access for L1 support
- **Permissions**:
  - Pods: get, list, watch, delete (restart only)
  - Pod logs: read-only
  - All other resources: read-only
  - NO exec, NO secrets
- **JIT Required**: Yes
- **Excludes**: kube-system, kube-public, gatekeeper-system

#### `project-deployment-temp`
- **Purpose**: Temporary deployment access for project engineers
- **Permissions**: Similar to app-namespace-operator, with secrets CRUD
- **JIT Required**: Yes
- **Max Duration**: 8 hours (enforced via PIM)

---

## Deployment Guide

### Prerequisites

1. **AKS Cluster** deployed with Azure RBAC enabled (use provided Bicep)
2. **Entra ID Groups** created following naming convention
3. **kubectl** configured with cluster access
4. **PIM** configured for elevated groups

### Step 1: Deploy AKS Infrastructure

#### Option A: Using Bicep

```bash
# Copy example parameters and update with your values
cp infra/bicep/main.bicepparam.example infra/bicep/main.bicepparam

# Edit the parameters file
vi infra/bicep/main.bicepparam

# Required values to update:
#   - clusterName: Your AKS cluster name (e.g., 'aks-acme-prod-eastus')
#   - location: Azure region (e.g., 'eastus', 'centralus', 'westeurope')
#   - clusterAdminGroupObjectIds: Array of Entra ID group object IDs
#   - logAnalyticsWorkspaceResourceId: (optional) Use existing or leave empty for new
#   - tags: Update environment, customer, cost center, owner

# Navigate to infra directory
cd infra/bicep/

# Deploy with Azure CLI
az deployment group create \
  --resource-group <RESOURCE_GROUP> \
  --template-file main.bicep \
  --parameters main.bicepparam

# Or use Bicep CLI
az bicep build --file main.bicep
az deployment group create \
  --resource-group <RESOURCE_GROUP> \
  --template-file main.json \
  --parameters @main.bicepparam
```

#### Option B: Using Terraform

```bash
# Copy example parameters and update with your values
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars

# Edit the parameters file
vi infra/terraform/terraform.tfvars

# Required values to update:
#   - cluster_name: Your AKS cluster name
#   - resource_group_name: Resource group for deployment
#   - location: Azure region
#   - cluster_admin_group_object_ids: Array of Entra ID group object IDs
#   - log_analytics_workspace_id: (optional) Use existing or leave empty

# Navigate to terraform directory
cd infra/terraform/

# Initialize and deploy
terraform init
terraform plan
terraform apply

# Get kubectl credentials
az aks get-credentials \
  --resource-group <RESOURCE_GROUP> \
  --name <CLUSTER_NAME> \
  --overwrite-existing
```

**Important Notes:**
- Parameter files with actual values (`terraform.tfvars`, `main.bicepparam`) are git-ignored
- Only template files (`*.example`) are tracked in source control
- Never commit files with actual subscription IDs, group IDs, or resource IDs

### Step 2: Configure Group Object IDs

Before applying RBAC manifests, update the placeholder values:

1. Open `rbac/cluster/cluster-roles.yaml`
2. Replace all `<*_GROUP_OBJECT_ID>` placeholders with actual Entra ID group object IDs
3. Repeat for `rbac/namespace/namespace-rolebindings.yaml`

**Finding Group Object IDs:**

```bash
# Using Azure CLI
az ad group show --group "AKS-{ClusterName}-InfraOps-L2-Elevated" --query id -o tsv

# Or in Azure Portal: Entra ID → Groups → Select Group → Overview → Object ID
```

### Step 3: Apply Cluster-Wide RBAC

```bash
# Get AKS credentials
az aks get-credentials --resource-group <RG> --name <CLUSTER_NAME>

# Apply cluster-wide roles and bindings
kubectl apply -k rbac/cluster/

# Verify
kubectl get clusterroles -l app.kubernetes.io/part-of=aks-iam-posture
kubectl get clusterrolebindings -l app.kubernetes.io/part-of=aks-iam-posture
```

### Step 4: Apply Namespace RBAC (per namespace)

```bash
# Create application namespace (if not exists)
kubectl create namespace <APP_NAMESPACE>

# Apply namespace roles
kubectl apply -f rbac/namespace/namespace-roles.yaml -n <APP_NAMESPACE>

# Apply namespace bindings (after updating group IDs)
kubectl apply -f rbac/namespace/namespace-rolebindings.yaml -n <APP_NAMESPACE>

# Verify
kubectl get roles -n <APP_NAMESPACE> -l app.kubernetes.io/part-of=aks-iam-posture
kubectl get rolebindings -n <APP_NAMESPACE> -l app.kubernetes.io/part-of=aks-iam-posture
```

### Step 5: Verify Audit Logging

```bash
# Check diagnostic settings on AKS cluster
az monitor diagnostic-settings list \
  --resource <AKS_RESOURCE_ID> \
  --output table

# Query audit logs in Log Analytics
az monitor log-analytics query \
  --workspace <LOG_ANALYTICS_WORKSPACE_ID> \
  --analytics-query "AzureDiagnostics | where Category == 'kube-audit' | take 10"
```

---

## Multi-Cluster Rollout

### Consistent Deployment Approach

For Nothing-Shared SaaS model with multiple customer clusters:

#### Option 1: CI/CD Pipeline (Recommended)

```yaml
# Example Azure DevOps Pipeline
stages:
  - stage: DeployRBAC
    jobs:
      - job: ApplyClusterRBAC
        steps:
          - task: KubernetesManifest@0
            inputs:
              action: deploy
              kubernetesServiceConnection: $(AKS_CONNECTION)
              manifests: rbac/cluster/cluster-roles.yaml
              
      - job: ApplyNamespaceRBAC
        steps:
          - ${{ each namespace in parameters.appNamespaces }}:
            - task: KubernetesManifest@0
              inputs:
                action: deploy
                kubernetesServiceConnection: $(AKS_CONNECTION)
                namespace: ${{ namespace }}
                manifests: |
                  rbac/namespace/namespace-roles.yaml
                  rbac/namespace/namespace-rolebindings.yaml
```

#### Option 2: GitOps with Flux/ArgoCD

```yaml
# flux-system/rbac-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: aks-rbac-cluster
  namespace: flux-system
spec:
  interval: 10m
  path: ./rbac/cluster
  prune: true
  sourceRef:
    kind: GitRepository
    name: aks-iam-config
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: aks-rbac-namespaces
  namespace: flux-system
spec:
  interval: 10m
  path: ./rbac/namespace
  prune: true
  sourceRef:
    kind: GitRepository
    name: aks-iam-config
  patches:
    - target:
        kind: RoleBinding
      patch: |
        - op: replace
          path: /metadata/namespace
          value: ${TARGET_NAMESPACE}
```

#### Option 3: Deployment Script

```bash
#!/bin/bash
# deploy-rbac.sh - Deploy RBAC to multiple clusters

CLUSTERS=("aks-customer1-prod" "aks-customer2-prod" "aks-customer3-prod")
APP_NAMESPACES=("app1" "app2" "app3")

for cluster in "${CLUSTERS[@]}"; do
  echo "Deploying to $cluster..."
  
  # Get credentials
  az aks get-credentials --resource-group "rg-$cluster" --name "$cluster" --overwrite-existing
  
  # Apply cluster RBAC
  kubectl apply -k rbac/cluster/
  
  # Apply namespace RBAC to each app namespace
  for ns in "${APP_NAMESPACES[@]}"; do
    kubectl apply -f rbac/namespace/namespace-roles.yaml -n "$ns"
    kubectl apply -f rbac/namespace/namespace-rolebindings.yaml -n "$ns"
  done
done
```

---

## JIT/PIM Configuration

### Entra ID PIM Setup (High-Level)

JIT elevation is managed via Entra ID Privileged Identity Management. This section provides guidance on group configuration.

#### 1. Create PIM-Eligible Groups

For each elevated group (e.g., `AKS-{Cluster}-InfraOps-L2-Elevated`):

1. Navigate to **Entra ID → Groups → New Group**
2. Set membership type to **Assigned**
3. Add users as **Eligible** members (not permanent)

#### 2. Configure PIM Settings

For each group, configure:

| Setting | Recommended Value |
|---------|-------------------|
| Maximum activation duration | 4-8 hours |
| Require justification | Yes |
| Require ticket information | Yes (for audit trail) |
| Require approval | Yes (for L2/L3 cluster admin) |
| Approvers | Security team or manager |
| Notification | On activation, send to security team |

#### 3. User Experience

When a user needs elevated access:

1. Navigate to **Entra ID → PIM → My Roles → Groups**
2. Find the relevant group and click **Activate**
3. Provide justification and ticket number
4. Wait for approval (if required)
5. Access is granted for configured duration
6. Access automatically revokes after expiration

---

## Validation Checklist

### Pre-Deployment Checks

- [ ] Entra ID groups created following naming convention
- [ ] Group object IDs obtained and inserted into YAML files
- [ ] PIM configured for elevated groups
- [ ] AKS cluster deployed with Azure RBAC enabled
- [ ] Local accounts disabled on AKS cluster
- [ ] Log Analytics workspace created/configured

### Post-Deployment Validation

After deploying RBAC, use both automated validation scripts and manual checks:

#### Automated Validation with Scripts

**1. Infrastructure and RBAC Configuration Validation**

```bash
./scripts/validate-rbac.sh <RESOURCE_GROUP> <CLUSTER_NAME> <LAW_NAME>
```

This script performs comprehensive checks:
- Azure RBAC for Kubernetes is disabled (using native K8s RBAC)
- Local accounts disabled on AKS
- Custom RBAC ClusterRoles deployed
- Cluster-admin role not broadly assigned
- System namespace access properly restricted
- Diagnostic settings configured correctly
- Audit logs flowing to Log Analytics workspace

**2. Persona Permission Validation**

```bash
# Create test account configuration
cp docs/group-config-template.env demo-accounts-<CLUSTER_NAME>.env

# Edit to add test user UPNs and group object IDs for each persona:
#   INFRA_OPS_L2_USER="test-infraops@yourtenant.onmicrosoft.com"
#   INFRA_OPS_L2_GROUP_ID="0a09b16f-a524-4214-ab1b-cdceaa89c41a"
#   APP_SUPPORT_L2_USER="test-appsupport@yourtenant.onmicrosoft.com"
#   APP_SUPPORT_L2_GROUP_ID="f357733b-357a-4a36-8422-cc700f018c84"
#   # ... etc for all personas

# Run persona validation
./scripts/validate-persona-permissions.sh demo-accounts-<CLUSTER_NAME>.env
```

**What the persona validation script tests:**

For each persona, it uses `kubectl auth can-i` to impersonate users and validate:

| Persona | Tests | Validates |
|---------|-------|----------|
| **Infra Ops L2** | 5 | Cluster-wide admin, kube-system access, node management, RBAC creation |
| **Platform SRE L3** | 5 | Cluster-wide admin, namespace creation, node management, RBAC creation |
| **App Support L2** | 8 | Namespace-scoped: view pods/logs, exec, scale, restart; NO cluster-wide, NO kube-system |
| **Command Centre L1** | 7 | Namespace read-only: view pods/logs/services; NO exec, NO delete, NO cluster-wide |
| **Cloud Deployment** | 6 | Namespace deploy only: create deployments/services; NO exec, NO pod delete |
| **Viewer** | 6 | Cluster-wide read-only: view all resources; NO modifications, NO exec |

**Example output:**

```
==============================================
AKS Persona Permission Validation
==============================================
Config: demo-accounts-prod-cluster.env
==============================================

[1] Testing Infra Ops L2: test-infraops@company.com
Expected: Full cluster admin, including kube-system access
Group: 0a09b16f-a524-4214-ab1b-cdceaa89c41a
  ✓ PASS: Can view pods (cluster-wide)
  ✓ PASS: Can create deployments
  ✓ PASS: Can delete nodes
  ✓ PASS: Can access kube-system
  ✓ PASS: Can create cluster roles

[3] Testing App Support L2: test-appsupport@company.com
Expected: Full edit access in namespaces, no cluster-wide
Group: f357733b-357a-4a36-8422-cc700f018c84
  ✓ PASS: Can view pods in default
  ✓ PASS: Can view logs in default
  ✓ PASS: Can exec into pods
  ✓ PASS: Can scale deployments
  ✓ PASS: Can restart pods
  ✓ PASS: Cannot view pods cluster-wide
  ✓ PASS: Cannot access kube-system
  ✓ PASS: Cannot create cluster roles

==============================================
✓ All tests passed!
```

**Note:** This script simulates permissions using `kubectl auth can-i --as=<user> --as-group=<group-id>`, which tests RBAC rules without requiring actual user login. For end-to-end testing, users should activate PIM and test with real kubectl commands.

#### Manual Validation Checks

Perform these manual checks in addition to automated scripts:

#### 1. Verify Cluster Admin Not Broadly Assigned

```bash
# Check cluster-admin bindings - should only show elevated groups
kubectl get clusterrolebindings -o json | \
  jq '.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects: .subjects}'

# Expected: Only elevated L2/L3 groups bound to cluster-admin
```

#### 2. Verify App Support/Command Centre Cannot Access kube-system

```bash
# Test as App Support user (after PIM activation)
kubectl auth can-i get pods -n kube-system --as-group="<APP_SUPPORT_GROUP_ID>"
# Expected: no

kubectl auth can-i get pods -n <app-namespace> --as-group="<APP_SUPPORT_GROUP_ID>"
# Expected: yes
```

#### 3. Verify Permissions Are Least Privilege

**Manual permission checks using kubectl auth can-i:**

```bash
# Test L1 cannot exec
kubectl auth can-i create pods --subresource=exec -n <app-namespace> --as-group="<COMMAND_CENTRE_GROUP_ID>"
# Expected: no

# Test L1 can view logs
kubectl auth can-i get pods --subresource=log -n <app-namespace> --as-group="<COMMAND_CENTRE_GROUP_ID>"
# Expected: yes

# Test L1 cannot access secrets
kubectl auth can-i get secrets -n <app-namespace> --as-group="<COMMAND_CENTRE_GROUP_ID>"
# Expected: no

# Test App Support can exec
kubectl auth can-i create pods --subresource=exec -n <app-namespace> --as-group="<APP_SUPPORT_GROUP_ID>"
# Expected: yes

# Test App Support cannot access cluster-wide
kubectl auth can-i get pods --all-namespaces --as-group="<APP_SUPPORT_GROUP_ID>"
# Expected: no
```

**Or use the automated validation script** (recommended):

```bash
./scripts/validate-persona-permissions.sh demo-accounts-<CLUSTER_NAME>.env
```

#### 4. Verify Audit Logs Flowing

```bash
# Query Log Analytics for recent audit events
az monitor log-analytics query \
  --workspace <WORKSPACE_ID> \
  --analytics-query "
    AzureDiagnostics
    | where Category == 'kube-audit'
    | where TimeGenerated > ago(1h)
    | summarize count() by bin(TimeGenerated, 5m)
  "

# Expected: Non-zero counts showing audit events are being captured
```

#### 5. Full Validation Script

```bash
#!/bin/bash
# validate-rbac.sh

echo "=== RBAC Validation ==="

echo -e "\n1. Checking cluster-admin bindings..."
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name | grep cluster-admin

echo -e "\n2. Checking ClusterRoles deployed..."
kubectl get clusterroles -l app.kubernetes.io/part-of=aks-iam-posture

echo -e "\n3. Checking ClusterRoleBindings..."
kubectl get clusterrolebindings -l app.kubernetes.io/part-of=aks-iam-posture

echo -e "\n4. Checking namespace Roles (in default)..."
kubectl get roles -n default -l app.kubernetes.io/part-of=aks-iam-posture 2>/dev/null || echo "No roles in default namespace"

echo -e "\n5. Verifying Azure RBAC is enabled..."
az aks show --resource-group <RG> --name <CLUSTER> --query aadProfile.enableAzureRBAC

echo -e "\n6. Verifying local accounts disabled..."
az aks show --resource-group <RG> --name <CLUSTER> --query disableLocalAccounts

echo -e "\n=== Validation Complete ==="
```

---

## Troubleshooting

### Common Issues

#### "User does not have access"

1. Verify user is member of correct Entra ID group
2. Check if PIM activation is required and active
3. Verify group object ID in RoleBinding matches actual group

```bash
# Check effective permissions
kubectl auth can-i --list --as-group="<GROUP_ID>"
```

#### "Forbidden" errors after PIM activation

1. Token may need refresh - run `az login` again
2. Kubeconfig may be cached - delete and regenerate

```bash
# Refresh credentials
rm ~/.kube/config
az aks get-credentials --resource-group <RG> --name <CLUSTER>
```

#### Audit logs not appearing

1. Check diagnostic settings are configured
2. Verify Log Analytics workspace is accessible
3. Check for ingestion delays (can be 5-15 minutes)

```bash
# Verify diagnostic settings
az monitor diagnostic-settings show \
  --name <SETTING_NAME> \
  --resource <AKS_RESOURCE_ID>
```

### Support Contacts

For issues with this IAM implementation:
- **Platform Team**: platform-team@example.com
- **Security Team**: security@example.com

---

## Appendix: Azure RBAC Role Reference

When using Azure RBAC for Kubernetes authorization, these built-in roles are available:

| Azure Role | Kubernetes Equivalent | Scope |
|------------|----------------------|-------|
| Azure Kubernetes Service RBAC Cluster Admin | cluster-admin | Cluster |
| Azure Kubernetes Service RBAC Admin | admin | Namespace |
| Azure Kubernetes Service RBAC Writer | edit | Namespace |
| Azure Kubernetes Service RBAC Reader | view | Namespace |

These Azure roles can be assigned at:
- Subscription level (all clusters)
- Resource group level (all clusters in RG)
- Cluster level (single cluster)
- Namespace level (specific namespace)

The custom Kubernetes RBAC roles in this implementation provide **more granular control** than the built-in Azure roles, which is why we use both Azure RBAC for authentication and custom K8s RBAC for fine-grained authorization.
