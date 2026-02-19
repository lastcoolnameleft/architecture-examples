# AKS IAM Posture Implementation Reference

**Document Purpose:** This document describes the actual implementation of persona-based RBAC for Azure Kubernetes Service (AKS) clusters following Microsoft least-privilege guidance.

**Applicability:** Generic implementation suitable for enterprise SaaS platforms with isolated AKS clusters.

---

## Table of Contents

1. [Overview](#overview)
2. [Implementation Architecture](#implementation-architecture)
3. [Persona Definitions](#persona-definitions)
4. [Entra ID Group Structure](#entra-id-group-structure)
5. [Kubernetes RBAC Roles](#kubernetes-rbac-roles)
6. [Persona-to-Role Mappings](#persona-to-role-mappings)
7. [Validation Approach](#validation-approach)
8. [Security Features](#security-features)

---

## Overview

### Implementation Model

This implementation supports a **Nothing-Shared SaaS** architecture where each customer/environment receives an isolated AKS cluster. Access is controlled through:

- **Entra ID Integration** - All authentication via Azure Active Directory
- **Group-Based Access** - No individual user assignments
- **JIT Elevation via PIM** - Time-bound privileged access
- **Namespace Isolation** - Application teams cannot access system namespaces
- **Comprehensive Auditing** - All actions logged to Log Analytics

### Security Principles Applied

1. **Least Privilege** - Minimal permissions required for each role
2. **Separation of Duties** - Clear boundaries between operational responsibilities
3. **Defense in Depth** - Multiple layers of access control
4. **Zero Standing Privileges** - Elevated access requires JIT activation
5. **Audit Everything** - Complete audit trail for compliance

---

## Implementation Architecture

```
Entra ID (PIM)  →  Entra ID Groups  → Kubernetes RBAC → Workloads
     ↓                  ↓                  ↓               ↓
 JIT Activation    Group Object IDs   Role Bindings     Namespaces
```

### Access Flow

1. User activates PIM role assignment for Entra ID group
2. User authenticates to AKS cluster via `az aks get-credentials`
3. Kubernetes maps Entra ID group to ClusterRole/Role via (Cluster)RoleBinding
4. User executes kubectl commands with assigned permissions
5. Actions logged to Log Analytics workspace

---

## Persona Definitions

### Implemented Personas

Six operational personas were implemented based on enterprise operational requirements:

| Persona | Level | Scope | Primary Function |
|---------|-------|-------|------------------|
| Infra Operations Engineer | L2 | Cluster-wide | Platform health & infrastructure |
| Platform SRE | L3 | Cluster-wide | Deep troubleshooting & upgrades |
| Application Support Engineer | L2 | Namespace | Application troubleshooting |
| Command Centre Engineer | L1 | Namespace | Read-only monitoring & triage |
| Cloud Deployment Engineer | L2 | Namespace | Application deployments |
| Cluster Viewer | N/A | Cluster-wide | Read-only visibility |

---

## Persona Definitions (Detailed)

### 1. Infra Operations Engineer (L2)

**Purpose:** Maintain AKS platform health and stability across all namespaces

**Responsibilities:**
- Provision and scale infrastructure components
- Manage node pools and VMSS operations
- Troubleshoot cluster-wide issues (API server, controllers, CNI)
- Investigate networking issues (CNI, ingress, load balancers)
- Review cluster audit and health logs
- Perform backup and restore operations
- Monitor HPA, scaling, and utilization metrics

**Access Requirements:**
- Cluster-wide read/write/execute
- Full access to kube-system namespace
- Node management (create, delete, cordon, drain)
- RBAC management capabilities

**JIT Required:** Yes (via PIM)

---

### 2. Platform SRE (L3)

**Purpose:** Deep technical troubleshooting and cluster lifecycle management

**Responsibilities:**
- Diagnose complex CNI/API server failures
- Perform cluster upgrade operations
- Manage system add-ons and policy engines (OPA/Gatekeeper)
- Debug workload identity and authentication issues
- Tune cluster-wide configurations
- Architect infrastructure improvements

**Access Requirements:**
- Cluster-wide read/write/execute
- Full access to kube-system namespace
- Node management
- RBAC management capabilities
- System namespace operator privileges

**JIT Required:** Yes (via PIM)

---

### 3. Application Support Engineer (L2)

**Purpose:** Second-line application support and troubleshooting

**Responsibilities:**
- Troubleshoot application behavior in production
- View workload configurations and logs
- Execute commands in pods for debugging
- Restart pods to resolve issues
- Scale applications up/down
- Monitor application health metrics

**Access Requirements (Namespace-scoped):**
- **Read:** pods, deployments, services, configmaps, logs
- **Write:** configmaps, services, deployments
- **Execute:** pod exec, pod port-forward
- **Delete:** pods (for restarts)
- **Scale:** deployments, statefulsets
- **Secrets:** Read-only access

**Restrictions:**
- ❌ No kube-system access
- ❌ No cluster-wide access
- ❌ No RBAC modifications

**JIT Required:** Yes (via PIM)

---

### 4. Command Centre Engineer (L1)

**Purpose:** First-line monitoring, triage, and escalation

**Responsibilities:**
- Monitor application health and logs
- Perform preliminary triage
- Execute runbook procedures
- Escalate issues to L2/L3
- View service status and endpoints

**Access Requirements (Namespace-scoped):**
- **Read-only:** pods, logs, services, deployments, configmaps
- **No modifications** - escalate to L2 for actions

**Implementation Note:** This is intentionally MORE restrictive than some operational models. The implementation follows Microsoft least-privilege guidance by making L1 truly read-only, requiring escalation to L2 for any modifications.

**Restrictions:**
- ❌ No pod exec
- ❌ No pod delete
- ❌ No scaling operations
- ❌ No kube-system access
- ❌ No cluster-wide access
- ❌ No secret access

**JIT Required:** Yes (via PIM)

---

### 5. Cloud Deployment Engineer

**Purpose:** Application deployment and configuration management

**Responsibilities:**
- Deploy applications via CI/CD pipelines
- Modify workload configurations
- Update secrets and configmaps
- Validate deployment health
- Rollback failed deployments

**Access Requirements (Namespace-scoped):**
- **Full CRUD:** deployments, statefulsets, services, configmaps, secrets
- **Read:** pods, logs, events
- **Scale:** deployments, statefulsets

**Implementation Note:** This role is intentionally deployment-focused, following GitOps/IaC principles. Manual pod operations (exec, delete) are not granted to encourage infrastructure-as-code practices.

**Restrictions:**
- ❌ No pod exec (use deployments, not manual access)
- ❌ No manual pod delete (use deployment updates)
- ❌ No kube-system access
- ❌ No cluster-wide access

**JIT Required:** Yes (via PIM)

---

### 6. Cluster Viewer

**Purpose:** Standing read-only visibility for monitoring and reporting

**Responsibilities:**
- View cluster resources for monitoring
- Generate reports on resource utilization
- Dashboard visibility

**Access Requirements:**
- **Read-only cluster-wide:** pods, deployments, services, nodes, namespaces
- **No modifications**

**Restrictions:**
- ❌ No write operations
- ❌ No pod exec
- ❌ No secret access
- ✅ Can view most resources cluster-wide

**JIT Required:** No (standing access for operational visibility)

---

## Entra ID Group Structure

### Group Naming Convention

```
AKS-{ClusterName}-{Persona}-{Scope}-{ElevationType}
```

### Implemented Groups (Example: iam-sandbox-aks cluster)

| Group Name | Object ID | Persona | JIT |
|------------|-----------|---------|-----|
| AKS-iam-sandbox-aks-InfraOps-L2-Elevated | 0a09b16f-a524-4214-ab1b-cdceaa89c41a | Infra Ops L2 | ✅ |
| AKS-iam-sandbox-aks-PlatformSRE-L3-Elevated | 7adb8e6d-1308-4cb1-a4dc-afed4be3a2c6 | Platform SRE L3 | ✅ |
| AKS-iam-sandbox-aks-AppSupport-L2-Elevated | f357733b-357a-4a36-8422-cc700f018c84 | App Support L2 | ✅ |
| AKS-iam-sandbox-aks-CommandCentre-L1-Elevated | 0a413af6-6615-4307-8e7c-5dd885747b72 | Command Centre L1 | ✅ |
| AKS-iam-sandbox-aks-CloudDeployment-Elevated | e019cae8-4e7f-460e-b628-1d6a3b1d3661 | Cloud Deployment | ✅ |
| AKS-iam-sandbox-aks-ClusterViewer | 7e4b9f98-8052-44dd-9473-f895ff3a3fc1 | Viewer | ❌ |

### PIM Configuration (Elevated Groups)

For all groups with "Elevated" designation:

- **Maximum Duration:** 4-8 hours
- **Approval Required:** Yes (for L2/L3 cluster admin)
- **Justification Required:** Yes
- **Ticket Required:** Yes
- **Notification:** Security team on activation
- **Access Reviews:** Quarterly

---

## Kubernetes RBAC Roles

### Cluster-Scoped Roles

#### 1. cluster-readonly

**Type:** ClusterRole  
**Bound To:** Cluster Viewer group  
**Purpose:** Baseline cluster visibility

**Permissions:**
```yaml
- nodes: get, list, watch
- namespaces: get, list, watch
- storageclasses: get, list, watch
- persistentvolumes: get, list, watch
- customresourcedefinitions: get, list, watch
```

#### 2. system-namespace-operator

**Type:** ClusterRole  
**Bound To:** Infra Ops L2, Platform SRE L3  
**Purpose:** Full access to system namespaces

**Permissions:**
```yaml
- All resources in kube-system, kube-public, kube-node-lease: full CRUD
- Includes: pods/exec, pods/log, configmaps, secrets, services, etc.
```

#### 3. cluster-admin (Built-in)

**Type:** ClusterRole (Kubernetes built-in)  
**Bound To:** Infra Ops L2, Platform SRE L3  
**Purpose:** Cluster-wide administrative access

**Permissions:** All resources, all verbs, all API groups

---

### Namespace-Scoped Roles

#### 1. app-namespace-operator

**Type:** Role (namespace-scoped)  
**Bound To:** Application Support L2  
**Purpose:** Full operational access within application namespaces

**Key Permissions:**
```yaml
Pods:
  - get, list, watch, delete
  - pods/exec: create
  - pods/log: get, list, watch
  - pods/portforward: create

Workloads:
  - deployments: full CRUD + scale
  - statefulsets: full CRUD + scale
  - replicasets: get, list, watch, delete, scale
  - daemonsets: get, list, watch

Configuration:
  - configmaps: full CRUD
  - secrets: get, list, watch (READ ONLY)
  - services: full CRUD

Autoscaling:
  - horizontalpodautoscalers: full CRUD
  - poddisruptionbudgets: full CRUD

Networking:
  - ingresses: full CRUD
  - networkpolicies: full CRUD
```

**Excludes:** kube-system, kube-public, kube-node-lease, gatekeeper-system

#### 2. l1-restricted-operator

**Type:** Role (namespace-scoped)  
**Bound To:** Command Centre L1, Cluster Viewer  
**Purpose:** Read-only namespace access for monitoring and triage

**Permissions:**
```yaml
Read-only:
  - pods: get, list, watch
  - pods/log: get, list, watch
  - services: get, list, watch
  - configmaps: get, list, watch
  - deployments: get, list, watch
  - statefulsets: get, list, watch
  - jobs: get, list, watch
  - cronjobs: get, list, watch
  - events: get, list, watch

Explicitly NOT granted:
  - pods/exec
  - delete operations
  - create/update/patch operations
  - secrets access
```

#### 3. project-deployment-temp

**Type:** Role (namespace-scoped)  
**Bound To:** Cloud Deployment Engineer  
**Purpose:** Deployment-focused access for CI/CD operations

**Permissions:**
```yaml
Deployments & Services:
  - deployments: full CRUD
  - statefulsets: full CRUD
  - services: full CRUD
  - deployments/scale: get, update, patch
  - statefulsets/scale: get, update, patch

Configuration & Secrets:
  - configmaps: full CRUD
  - secrets: full CRUD

Monitoring:
  - pods: get, list, watch
  - pods/log: get, list, watch
  - events: get, list, watch

Explicitly NOT granted:
  - pods/exec (encourage GitOps over manual access)
  - pod delete (use deployment updates)
```

---

## Persona-to-Role Mappings

### Complete Mapping Table

| Persona | Entra ID Group | Kubernetes Roles | Scope | Validation Tests |
|---------|----------------|------------------|-------|------------------|
| **Infra Ops L2** | InfraOps-L2-Elevated | cluster-admin<br>system-namespace-operator | Cluster-wide | 5 tests |
| **Platform SRE L3** | PlatformSRE-L3-Elevated | cluster-admin<br>system-namespace-operator | Cluster-wide | 5 tests |
| **App Support L2** | AppSupport-L2-Elevated | app-namespace-operator | Namespace | 8 tests |
| **Command Centre L1** | CommandCentre-L1-Elevated | l1-restricted-operator | Namespace | 7 tests |
| **Cloud Deployment** | CloudDeployment-Elevated | project-deployment-temp | Namespace | 6 tests |
| **Cluster Viewer** | ClusterViewer | cluster-readonly<br>l1-restricted-operator | Cluster-wide<br>+ Namespace | 6 tests |

### Binding Mechanism

**Cluster-Scoped:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-elevated-binding
subjects:
- kind: Group
  name: "<ENTRA_ID_GROUP_OBJECT_ID>"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

**Namespace-Scoped:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-namespace-operator-binding
  namespace: <APPLICATION_NAMESPACE>
subjects:
- kind: Group
  name: "<ENTRA_ID_GROUP_OBJECT_ID>"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: app-namespace-operator
  apiGroup: rbac.authorization.k8s.io
```

---

## Validation Approach

### Two-Stage Validation

#### Stage 1: Infrastructure & Configuration Validation

**Script:** `validate-rbac.sh`

**Validates:**
1. ✅ Azure RBAC for Kubernetes is disabled (using native K8s RBAC)
2. ✅ Local accounts disabled on AKS
3. ✅ Custom RBAC ClusterRoles deployed
4. ✅ cluster-admin role not broadly assigned
5. ✅ System namespace access properly restricted
6. ✅ Diagnostic settings configured
7. ✅ Audit logs flowing to Log Analytics

**Usage:**
```bash
./scripts/validate-rbac.sh <RESOURCE_GROUP> <CLUSTER_NAME> <LAW_NAME>
```

#### Stage 2: Persona Permission Validation

**Script:** `validate-persona-permissions.sh`

**Approach:** Uses `kubectl auth can-i` to impersonate users and validate RBAC rules

**Test Types:**
- ✅ **Positive Tests:** Expected permissions work (e.g., App Support can exec)
- ❌ **Negative Tests:** Restricted permissions denied (e.g., cannot access kube-system)
- 🌐 **Scope Tests:** Cluster-wide vs namespace boundaries
- 🔒 **Privilege Tests:** Read vs write vs execute capabilities

**Usage:**
```bash
# Create config with test users
cp docs/group-config-template.env demo-accounts-<cluster>.env
# Edit to add user UPNs and group IDs

# Run validation
./scripts/validate-persona-permissions.sh demo-accounts-<cluster>.env
```

### Validation Results (Reference Implementation)

**Total Tests:** 41  
**All Tests Passed:** ✅

| Persona | Tests | Result |
|---------|-------|--------|
| Infra Ops L2 | 5 | ✅ PASS |
| Platform SRE L3 | 5 | ✅ PASS |
| App Support L2 | 8 | ✅ PASS |
| Command Centre L1 | 7 | ✅ PASS |
| Cloud Deployment | 6 | ✅ PASS |
| Cluster Viewer | 6 | ✅ PASS |

---

## Security Features

### Implemented Security Controls

#### 1. Authentication & Authorization
- ✅ **Entra ID Integration:** All users authenticate via Azure AD
- ✅ **No Local Accounts:** Kubernetes local accounts disabled
- ✅ **Group-Based Access:** Zero individual user assignments
- ✅ **Native Kubernetes RBAC:** Azure RBAC for Kubernetes disabled

#### 2. Privilege Management
- ✅ **JIT Elevation:** All elevated access via PIM (4-8 hour max)
- ✅ **Least Privilege:** Minimal permissions per persona
- ✅ **No Wildcard Permissions:** Explicit verbs and resources
- ✅ **Namespace Isolation:** App teams blocked from system namespaces

#### 3. Secrets Management
- ✅ **App Support:** Read-only secret access (no modifications)
- ✅ **L1 Users:** No secret access (escalate to L2)
- ✅ **Deployment Roles:** Full CRUD on secrets (CI/CD needs)
- ✅ **Cluster Admins:** Full access for platform operations

#### 4. Monitoring & Auditing
- ✅ **Audit Logging:** All API calls logged to Log Analytics
- ✅ **Resource-Specific Tables:** AKSAuditAdmin, AKSControlPlane logs
- ✅ **90-Day Retention:** Compliance-ready retention period
- ✅ **Guard Logs:** Entra ID authentication events

#### 5. Deployment Security
- ✅ **GitOps Principles:** Deployment roles encourage IaC over manual ops
- ✅ **No Manual Pod Ops:** Deployers use workload controllers
- ✅ **No Console Access:** Deployment roles lack pod exec

#### 6. Network Isolation
- ✅ **Namespace Boundaries:** Network policies per namespace
- ✅ **Ingress Controls:** L7 routing via ingress controllers
- ✅ **Service Mesh Ready:** Architecture supports Istio/Linkerd

---

## Deployment Sequence

### Standard Rollout Procedure

1. **Deploy Infrastructure** (Terraform/Bicep)
   - AKS cluster with Entra ID integration
   - Log Analytics workspace
   - Diagnostic settings

2. **Create Entra ID Groups**
   - Follow naming convention
   - Configure PIM for elevated groups

3. **Update RBAC Manifests**
   - Insert group object IDs
   - Review role definitions

4. **Apply Cluster RBAC**
   ```bash
   kubectl apply -k rbac/cluster/
   ```

5. **Apply Namespace RBAC** (per app namespace)
   ```bash
   kubectl apply -f rbac/namespace/namespace-roles.yaml -n <namespace>
   kubectl apply -f rbac/namespace/namespace-rolebindings.yaml -n <namespace>
   ```

6. **Validate Configuration**
   ```bash
   ./scripts/validate-rbac.sh <RG> <CLUSTER> <LAW>
   ```

7. **Validate Permissions**
   ```bash
   ./scripts/validate-persona-permissions.sh <config-file>
   ```

8. **Test with Real Users**
   - Activate PIM assignments
   - Test kubectl commands
   - Verify audit logs

---

## Maintenance & Operations

### Adding New Users

1. Add user to appropriate Entra ID group (PIM-eligible)
2. User activates PIM assignment when needed
3. No Kubernetes configuration changes required

### Adding New Namespaces

1. Create namespace: `kubectl create namespace <name>`
2. Apply roles: `kubectl apply -f rbac/namespace/namespace-roles.yaml -n <name>`
3. Apply bindings: `kubectl apply -f rbac/namespace/namespace-rolebindings.yaml -n <name>`

### Modifying Permissions

1. Update role YAML files in `rbac/` directories
2. Apply changes: `kubectl apply -k rbac/cluster/` or per namespace
3. Re-run validation scripts
4. Test with affected users

### Access Reviews

- **Quarterly:** Review PIM group memberships
- **Annual:** Review and update role definitions
- **On-Demand:** When operational requirements change

---

## References

- **Microsoft AKS RBAC Documentation:** https://learn.microsoft.com/azure/aks/azure-ad-rbac
- **Kubernetes RBAC Best Practices:** https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **Entra ID PIM:** https://learn.microsoft.com/entra/id-governance/privileged-identity-management/

---

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Implementation Status:** Production-Ready
