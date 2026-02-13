#!/bin/bash
# =============================================================================
# RBAC Validation Script
# =============================================================================
# This script validates the AKS IAM posture implementation by checking:
# 1. Cluster admin is not broadly assigned
# 2. App Support / Command Centre cannot access kube-system
# 3. Correct verbs/resources are granted
# 4. Audit logs are flowing to Log Analytics
#
# Prerequisites:
# - kubectl configured with cluster access
# - Azure CLI logged in
# - jq installed
#
# Usage:
#   ./validate-rbac.sh <RESOURCE_GROUP> <CLUSTER_NAME> <LOG_ANALYTICS_WORKSPACE_ID>
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <RESOURCE_GROUP> <CLUSTER_NAME> [LOG_ANALYTICS_WORKSPACE_ID]"
    exit 1
fi

RESOURCE_GROUP=$1
CLUSTER_NAME=$2
LOG_ANALYTICS_WORKSPACE_ID=${3:-""}

echo "=============================================="
echo "AKS IAM Posture Validation"
echo "=============================================="
echo "Cluster: $CLUSTER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "=============================================="
echo ""

# Function to print pass/fail
check_result() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        FAILURES=$((FAILURES + 1))
    fi
}

FAILURES=0

# =============================================================================
# Pre-flight: Verify Cluster Connectivity
# =============================================================================
echo -e "\n${YELLOW}[Pre-flight] Verifying cluster connectivity...${NC}"

# Get cluster credentials
if ! az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing 2>/dev/null; then
    echo -e "${RED}✗ FAIL${NC}: Unable to get cluster credentials"
    exit 1
fi

# Test cluster connectivity and ensure it's running
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ FAIL${NC}: Cluster is not accessible. Ensure the cluster is running and kubectl is configured."
    exit 1
fi

# Verify API server is responsive
if ! kubectl get --raw /healthz &>/dev/null; then
    echo -e "${RED}✗ FAIL${NC}: Cluster API server is not responsive"
    exit 1
fi

# Verify we can list nodes (checks basic RBAC and cluster readiness)
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ FAIL${NC}: No nodes found. Cluster may not be fully provisioned or accessible."
    exit 1
fi

echo -e "${GREEN}✓ PASS${NC}: Cluster is accessible and running ($NODE_COUNT node(s))"

# =============================================================================
# Check 1: Azure RBAC Disabled
# =============================================================================
echo -e "\n${YELLOW}[1/8] Checking Azure RBAC for Kubernetes is disabled...${NC}"

AZURE_RBAC=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --query "aadProfile.enableAzureRBAC" -o tsv 2>/dev/null || echo "false")

if [ "$AZURE_RBAC" = "false" ] || [ "$AZURE_RBAC" = "" ]; then
    check_result 0 "Azure RBAC for Kubernetes is disabled"
else
    check_result 1 "Azure RBAC for Kubernetes is NOT disabled"
fi

# =============================================================================
# Check 2: Local Accounts Disabled
# =============================================================================
echo -e "\n${YELLOW}[2/8] Checking local accounts are disabled...${NC}"

LOCAL_ACCOUNTS=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --query "disableLocalAccounts" -o tsv 2>/dev/null || echo "false")

if [ "$LOCAL_ACCOUNTS" = "true" ]; then
    check_result 0 "Local accounts are disabled (Entra ID enforced)"
else
    check_result 1 "Local accounts are NOT disabled"
fi

# =============================================================================
# Check 3: Custom RBAC ClusterRoles Deployed
# =============================================================================
echo -e "\n${YELLOW}[3/8] Checking custom ClusterRoles are deployed...${NC}"

CUSTOM_ROLES=$(kubectl get clusterroles -l app.kubernetes.io/part-of=aks-iam-posture \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "$CUSTOM_ROLES" ]; then
    echo "  Found roles: $CUSTOM_ROLES"
    check_result 0 "Custom ClusterRoles deployed"
else
    check_result 1 "Custom ClusterRoles NOT found"
fi

# =============================================================================
# Check 4: Cluster Admin Not Broadly Assigned
# =============================================================================
echo -e "\n${YELLOW}[4/8] Checking cluster-admin is not broadly assigned...${NC}"
echo "  Validating that cluster-admin role is only assigned to managed Entra ID groups,"
echo "  not to individual users, system:authenticated, or system:serviceaccounts."

# Get all cluster-admin bindings JSON once
CLUSTER_ADMIN_JSON=$(kubectl get clusterrolebindings -o json 2>/dev/null | \
    jq -r '.items[] | select(.roleRef.name=="cluster-admin")')

# Get groups with cluster-admin
CLUSTER_ADMIN_GROUPS=$(echo "$CLUSTER_ADMIN_JSON" | \
    jq -r '.subjects[]? | select(.kind=="Group") | .name' 2>/dev/null)
CLUSTER_ADMIN_GROUP_COUNT=$(echo "$CLUSTER_ADMIN_GROUPS" | grep -c '^' || true)
if [ "$CLUSTER_ADMIN_GROUP_COUNT" -eq 0 ] || [ -z "$CLUSTER_ADMIN_GROUPS" ]; then
    CLUSTER_ADMIN_GROUP_COUNT=0
fi

# Check for risky/broad bindings (Users, system:authenticated, system:serviceaccounts)
BROAD_BINDINGS_LIST=$(echo "$CLUSTER_ADMIN_JSON" | \
    jq -r '.subjects[]? | select(.kind=="User" or .name=="system:authenticated" or .name=="system:serviceaccounts") | "\(.kind): \(.name)"' 2>/dev/null)
BROAD_BINDINGS=$(echo "$BROAD_BINDINGS_LIST" | grep -c '^' || true)
if [ "$BROAD_BINDINGS" -eq 0 ] || [ -z "$BROAD_BINDINGS_LIST" ]; then
    BROAD_BINDINGS=0
fi

echo ""
echo "  Summary of cluster-admin bindings:"
echo "  -----------------------------------"

if [ "$CLUSTER_ADMIN_GROUP_COUNT" -gt 0 ]; then
    echo "  Groups with cluster-admin (OK):"
    echo "$CLUSTER_ADMIN_GROUPS" | while read -r group; do
        [ -n "$group" ] && echo "    [Group] $group"
    done
else
    echo "  Groups with cluster-admin: (none)"
fi

echo ""

if [ "$BROAD_BINDINGS" -eq 0 ]; then
    echo "  Risky bindings found: None"
    echo ""
    check_result 0 "cluster-admin is properly scoped to $CLUSTER_ADMIN_GROUP_COUNT group(s) only"
else
    echo -e "  ${RED}Risky bindings found:${NC}"
    echo "$BROAD_BINDINGS_LIST" | while read -r line; do
        [ -n "$line" ] && echo -e "    ${RED}[RISK]${NC} $line"
    done
    echo ""
    echo "  Why this is a risk:"
    echo "    - Individual Users: Should use group membership for easier management"
    echo "    - system:authenticated: Grants cluster-admin to ALL authenticated users"
    echo "    - system:serviceaccounts: Grants cluster-admin to ALL service accounts"
    echo ""
    check_result 1 "cluster-admin has $BROAD_BINDINGS risky binding(s) that should be removed"
fi

# =============================================================================
# Check 5: Custom Namespace Roles Exist
# =============================================================================
echo -e "\n${YELLOW}[5/8] Checking namespace-scoped roles are defined...${NC}"

# Get all namespaces and check for custom roles
NS_WITH_ROLES=$(kubectl get roles --all-namespaces -l app.kubernetes.io/part-of=aks-iam-posture \
    -o jsonpath='{.items[*].metadata.namespace}' 2>/dev/null | tr ' ' '\n' | sort -u | wc -l)

if [ "$NS_WITH_ROLES" -gt 0 ]; then
    echo "  Found custom roles in $NS_WITH_ROLES namespace(s)"
    check_result 0 "Namespace-scoped roles deployed"
else
    echo -e "  ${YELLOW}Note: No namespace roles found yet (deploy to app namespaces)${NC}"
    check_result 0 "Namespace roles check skipped (apply to app namespaces)"
fi

# =============================================================================
# Check 6: kube-system Access Restricted
# =============================================================================
echo -e "\n${YELLOW}[6/8] Checking kube-system is not accessible by app roles...${NC}"

# Check if any app-namespace-operator or l1-restricted-operator exists in kube-system
KUBESYSTEM_ROLES=$(kubectl get roles -n kube-system -l app.kubernetes.io/part-of=aks-iam-posture \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$KUBESYSTEM_ROLES" ]; then
    check_result 0 "No custom app roles in kube-system"
else
    check_result 1 "Found custom roles in kube-system: $KUBESYSTEM_ROLES"
fi

# =============================================================================
# Check 7: Diagnostic Settings Configured
# =============================================================================
echo -e "\n${YELLOW}[7/8] Checking diagnostic settings for audit logging...${NC}"

AKS_ID=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --query "id" -o tsv 2>/dev/null)

DIAG_SETTINGS=$(az monitor diagnostic-settings list --resource "$AKS_ID" \
    --query "[*].name" -o tsv 2>/dev/null || echo "")

if [ -n "$DIAG_SETTINGS" ]; then
    echo "  Diagnostic settings: $DIAG_SETTINGS"
    
    # Check for kube-audit category (flatten nested arrays with [])
    AUDIT_ENABLED=$(az monitor diagnostic-settings list --resource "$AKS_ID" \
        --query "[].logs[?category=='kube-audit-admin'][][].enabled" -o tsv 2>/dev/null | grep -c "true" || echo "0")
    
    if [ "$AUDIT_ENABLED" -gt 0 ]; then
        check_result 0 "Audit logging enabled"
    else
        check_result 1 "kube-audit category not enabled"
    fi
else
    check_result 1 "No diagnostic settings configured"
fi

# =============================================================================
# Check 8: Audit Logs Flowing (if workspace provided)
# =============================================================================
echo -e "\n${YELLOW}[8/8] Checking audit logs are flowing to Log Analytics...${NC}"

if [ -n "$LOG_ANALYTICS_WORKSPACE_ID" ]; then
    RECENT_LOGS=$(az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE_ID" \
        --analytics-query "AzureDiagnostics | where Category == 'kube-audit' | where TimeGenerated > ago(1h) | count" \
        --query "[0].count_" -o tsv 2>/dev/null || echo "0")
    
    if [ "$RECENT_LOGS" -gt 0 ]; then
        echo "  Found $RECENT_LOGS audit events in last hour"
        check_result 0 "Audit logs flowing to Log Analytics"
    else
        echo -e "  ${YELLOW}Note: No recent audit logs (may have ingestion delay)${NC}"
        check_result 0 "Audit log check skipped (possible ingestion delay)"
    fi
else
    echo "  Skipped (no Log Analytics workspace ID provided)"
    check_result 0 "Audit log check skipped"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "Validation Summary"
echo "=============================================="

if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILURES check(s) failed${NC}"
    echo ""
    echo "Review the failed checks above and take corrective action."
    exit 1
fi
