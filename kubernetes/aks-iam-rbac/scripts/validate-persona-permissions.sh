#!/bin/bash
# =============================================================================
# Persona Permission Validation Script
# =============================================================================
# This script validates that each persona has the expected permissions in the
# AKS cluster by simulating Entra ID group membership using kubectl auth can-i.
#
# Usage: ./validate-persona-permissions.sh <CONFIG_FILE>
#
# The config file should define:
#   - User UPNs for each persona (e.g., INFRA_OPS_L2_USER)
#   - Group Object IDs for each role (e.g., INFRA_OPS_L2_GROUP_ID)
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <CONFIG_FILE>"
    exit 1
fi

CONFIG_FILE=$1

# Verify config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Source the config file
source "$CONFIG_FILE"

echo "=============================================="
echo "AKS Persona Permission Validation"
echo "=============================================="
echo "Config: $CONFIG_FILE"
echo "=============================================="
echo ""

# Helper function to test a result
test_result() {
    local expected=$1
    local actual=$2
    local description=$3
    
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓ PASS${NC}: $description"
    else
        echo -e "  ${RED}✗ FAIL${NC}: $description (expected: $expected, got: $actual)"
        FAILURES=$((FAILURES + 1))
    fi
}

# Helper function to check permissions
# Usage: can_i <user> <verb> <resource> [namespace] [group-id]
# Note: Pass "--all-namespaces" as namespace to test cluster-wide access
can_i() {
    local user=$1
    local verb=$2
    local resource=$3
    local namespace=${4:-}
    local group_id=${5:-}
    
    # Handle subresource notation (e.g., "pods/log" or "pods/exec")
    local base_resource="$resource"
    local subresource=""
    if [[ "$resource" == *"/"* ]]; then
        base_resource="${resource%%/*}"
        subresource="${resource##*/}"
    fi
    
    local cmd="kubectl auth can-i $verb $base_resource"
    
    if [ -n "$subresource" ]; then
        cmd="$cmd --subresource=$subresource"
    fi
    
    if [ -n "$group_id" ]; then
        cmd="$cmd --as-group=$group_id"
    fi
    
    cmd="$cmd --as=$user"
    
    if [ "$namespace" = "--all-namespaces" ]; then
        cmd="$cmd --all-namespaces"
    elif [ -n "$namespace" ]; then
        cmd="$cmd -n $namespace"
    fi
    
    if $cmd &>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Counter for failures
FAILURES=0

# Test namespace for namespace-scoped permissions
TEST_NAMESPACE="default"

# Ensure test namespace exists
if ! kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
    kubectl create namespace "$TEST_NAMESPACE" 2>/dev/null || true
fi

# =============================================================================
# Test 1: Infra Ops L2 (Elevated Admin)
# =============================================================================
if [ -n "$INFRA_OPS_L2_USER" ] && [ -n "$INFRA_OPS_L2_GROUP_ID" ]; then
    echo -e "${BLUE}[1] Testing Infra Ops L2 (Elevated): $INFRA_OPS_L2_USER${NC}"
    echo "Expected: Full cluster admin, including kube-system access"
    echo "Group: $INFRA_OPS_L2_GROUP_ID"
    
    test_result "yes" "$(can_i "$INFRA_OPS_L2_USER" get pods "" "$INFRA_OPS_L2_GROUP_ID")" "Can view pods (cluster-wide)"
    test_result "yes" "$(can_i "$INFRA_OPS_L2_USER" create deployments "" "$INFRA_OPS_L2_GROUP_ID")" "Can create deployments"
    test_result "yes" "$(can_i "$INFRA_OPS_L2_USER" delete nodes "" "$INFRA_OPS_L2_GROUP_ID")" "Can delete nodes"
    test_result "yes" "$(can_i "$INFRA_OPS_L2_USER" get pods "kube-system" "$INFRA_OPS_L2_GROUP_ID")" "Can access kube-system"
    test_result "yes" "$(can_i "$INFRA_OPS_L2_USER" create clusterroles "" "$INFRA_OPS_L2_GROUP_ID")" "Can create cluster roles"
    
    echo ""
fi

# =============================================================================
# Test 2: Platform SRE L3 (Cluster Admin)
# =============================================================================
if [ -n "$PLATFORM_SRE_L3_USER" ] && [ -n "$PLATFORM_SRE_L3_GROUP_ID" ]; then
    echo -e "${BLUE}[2] Testing Platform SRE L3 (Admin): $PLATFORM_SRE_L3_USER${NC}"
    echo "Expected: Full cluster admin access"
    echo "Group: $PLATFORM_SRE_L3_GROUP_ID"
    
    test_result "yes" "$(can_i "$PLATFORM_SRE_L3_USER" get pods "" "$PLATFORM_SRE_L3_GROUP_ID")" "Can view pods (cluster-wide)"
    test_result "yes" "$(can_i "$PLATFORM_SRE_L3_USER" create namespaces "" "$PLATFORM_SRE_L3_GROUP_ID")" "Can create namespaces"
    test_result "yes" "$(can_i "$PLATFORM_SRE_L3_USER" get pods "kube-system" "$PLATFORM_SRE_L3_GROUP_ID")" "Can access kube-system"
    test_result "yes" "$(can_i "$PLATFORM_SRE_L3_USER" create clusterroles "" "$PLATFORM_SRE_L3_GROUP_ID")" "Can create cluster roles"
    test_result "yes" "$(can_i "$PLATFORM_SRE_L3_USER" delete nodes "" "$PLATFORM_SRE_L3_GROUP_ID")" "Can manage nodes"
    
    echo ""
fi

# =============================================================================
# Test 3: App Support L2 (Namespace Editor)
# =============================================================================
if [ -n "$APP_SUPPORT_L2_USER" ] && [ -n "$APP_SUPPORT_L2_GROUP_ID" ]; then
    echo -e "${BLUE}[3] Testing App Support L2 (Editor): $APP_SUPPORT_L2_USER${NC}"
    echo "Expected: Full edit access in namespaces, no cluster-wide or kube-system"
    echo "Group: $APP_SUPPORT_L2_GROUP_ID"
    
    # Positive tests - should have access
    test_result "yes" "$(can_i "$APP_SUPPORT_L2_USER" get pods "$TEST_NAMESPACE" "$APP_SUPPORT_L2_GROUP_ID")" "Can view pods in $TEST_NAMESPACE"
    test_result "yes" "$(can_i "$APP_SUPPORT_L2_USER" get pods/log "$TEST_NAMESPACE" "$APP_SUPPORT_L2_GROUP_ID")" "Can view logs in $TEST_NAMESPACE"
    test_result "yes" "$(can_i "$APP_SUPPORT_L2_USER" create pods/exec "$TEST_NAMESPACE" "$APP_SUPPORT_L2_GROUP_ID")" "Can exec into pods"
    test_result "yes" "$(can_i "$APP_SUPPORT_L2_USER" patch deployments "$TEST_NAMESPACE" "$APP_SUPPORT_L2_GROUP_ID")" "Can scale deployments"
    test_result "yes" "$(can_i "$APP_SUPPORT_L2_USER" delete pods "$TEST_NAMESPACE" "$APP_SUPPORT_L2_GROUP_ID")" "Can restart pods"
    
    # Negative tests - should NOT have access
    test_result "no" "$(can_i "$APP_SUPPORT_L2_USER" get pods "--all-namespaces" "$APP_SUPPORT_L2_GROUP_ID")" "Cannot view pods cluster-wide"
    test_result "no" "$(can_i "$APP_SUPPORT_L2_USER" get pods "kube-system" "$APP_SUPPORT_L2_GROUP_ID")" "Cannot access kube-system"
    test_result "no" "$(can_i "$APP_SUPPORT_L2_USER" create clusterroles "" "$APP_SUPPORT_L2_GROUP_ID")" "Cannot create cluster roles"
    
    echo ""
fi

# =============================================================================
# Test 4: Command Centre L1 (Namespace Viewer)
# =============================================================================
if [ -n "$COMMAND_CENTRE_L1_USER" ] && [ -n "$COMMAND_CENTRE_L1_GROUP_ID" ]; then
    echo -e "${BLUE}[4] Testing Command Centre L1 (Viewer): $COMMAND_CENTRE_L1_USER${NC}"
    echo "Expected: Read-only in namespaces, no exec, no cluster-wide"
    echo "Group: $COMMAND_CENTRE_L1_GROUP_ID"
    
    # Positive tests - should have access
    test_result "yes" "$(can_i "$COMMAND_CENTRE_L1_USER" get pods "$TEST_NAMESPACE" "$COMMAND_CENTRE_L1_GROUP_ID")" "Can view pods in $TEST_NAMESPACE"
    test_result "yes" "$(can_i "$COMMAND_CENTRE_L1_USER" get pods/log "$TEST_NAMESPACE" "$COMMAND_CENTRE_L1_GROUP_ID")" "Can view logs"
    test_result "yes" "$(can_i "$COMMAND_CENTRE_L1_USER" get services "$TEST_NAMESPACE" "$COMMAND_CENTRE_L1_GROUP_ID")" "Can view services"
    
    # Negative tests - should NOT have access
    test_result "no" "$(can_i "$COMMAND_CENTRE_L1_USER" create pods/exec "$TEST_NAMESPACE" "$COMMAND_CENTRE_L1_GROUP_ID")" "Cannot exec into pods"
    test_result "no" "$(can_i "$COMMAND_CENTRE_L1_USER" delete pods "$TEST_NAMESPACE" "$COMMAND_CENTRE_L1_GROUP_ID")" "Cannot delete pods"
    test_result "no" "$(can_i "$COMMAND_CENTRE_L1_USER" get pods "kube-system" "$COMMAND_CENTRE_L1_GROUP_ID")" "Cannot access kube-system"
    test_result "no" "$(can_i "$COMMAND_CENTRE_L1_USER" get pods "--all-namespaces" "$COMMAND_CENTRE_L1_GROUP_ID")" "Cannot view cluster-wide"
    
    echo ""
fi

# =============================================================================
# Test 5: Cloud Deployment (Namespace Editor - Restricted)
# =============================================================================
if [ -n "$CLOUD_DEPLOYMENT_USER" ] && [ -n "$CLOUD_DEPLOYMENT_GROUP_ID" ]; then
    echo -e "${BLUE}[5] Testing Cloud Deployment (Deployer): $CLOUD_DEPLOYMENT_USER${NC}"
    echo "Expected: Can deploy apps but no exec/delete, no cluster-wide"
    echo "Group: $CLOUD_DEPLOYMENT_GROUP_ID"
    
    # Positive tests - should have access
    test_result "yes" "$(can_i "$CLOUD_DEPLOYMENT_USER" create deployments "$TEST_NAMESPACE" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Can create deployments"
    test_result "yes" "$(can_i "$CLOUD_DEPLOYMENT_USER" create services "$TEST_NAMESPACE" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Can create services"
    test_result "yes" "$(can_i "$CLOUD_DEPLOYMENT_USER" get pods "$TEST_NAMESPACE" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Can view pods"
    
    # Negative tests - should NOT have access
    test_result "no" "$(can_i "$CLOUD_DEPLOYMENT_USER" create pods/exec "$TEST_NAMESPACE" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Cannot exec into pods"
    test_result "no" "$(can_i "$CLOUD_DEPLOYMENT_USER" delete pods "$TEST_NAMESPACE" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Cannot delete pods directly"
    test_result "no" "$(can_i "$CLOUD_DEPLOYMENT_USER" get pods "--all-namespaces" "$CLOUD_DEPLOYMENT_GROUP_ID")" "Cannot view cluster-wide"
    
    echo ""
fi

# =============================================================================
# Test 6: Project Deployment (Similar to Cloud Deployment)
# =============================================================================
if [ -n "$PROJECT_DEPLOYMENT_USER" ] && [ -n "$PROJECT_DEPLOYMENT_GROUP_ID" ]; then
    echo -e "${BLUE}[6] Testing Project Deployment (Deployer): $PROJECT_DEPLOYMENT_USER${NC}"
    echo "Expected: Can deploy apps but limited management rights"
    echo "Group: $PROJECT_DEPLOYMENT_GROUP_ID"
    
    test_result "yes" "$(can_i "$PROJECT_DEPLOYMENT_USER" create deployments "$TEST_NAMESPACE" "$PROJECT_DEPLOYMENT_GROUP_ID")" "Can create deployments"
    test_result "yes" "$(can_i "$PROJECT_DEPLOYMENT_USER" get pods "$TEST_NAMESPACE" "$PROJECT_DEPLOYMENT_GROUP_ID")" "Can view pods"
    test_result "no" "$(can_i "$PROJECT_DEPLOYMENT_USER" get pods "--all-namespaces" "$PROJECT_DEPLOYMENT_GROUP_ID")" "Cannot view cluster-wide"
    
    echo ""
fi

# =============================================================================
# Test 7: Viewer (Cluster-wide Read-only)
# =============================================================================
if [ -n "$VIEWER_USER" ] && [ -n "$CLUSTER_VIEWER_GROUP_ID" ]; then
    echo -e "${BLUE}[7] Testing Viewer (Read-Only): $VIEWER_USER${NC}"
    echo "Expected: Read-only cluster-wide, no modifications"
    echo "Group: $CLUSTER_VIEWER_GROUP_ID"
    
    # Positive tests - should have access
    test_result "yes" "$(can_i "$VIEWER_USER" get pods "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Can view pods in namespaces"
    test_result "yes" "$(can_i "$VIEWER_USER" get deployments "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Can view deployments"
    test_result "yes" "$(can_i "$VIEWER_USER" get services "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Can view services"
    
    # Negative tests - should NOT have access
    test_result "no" "$(can_i "$VIEWER_USER" create pods "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Cannot create resources"
    test_result "no" "$(can_i "$VIEWER_USER" delete pods "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Cannot delete resources"
    test_result "no" "$(can_i "$VIEWER_USER" create pods/exec "$TEST_NAMESPACE" "$CLUSTER_VIEWER_GROUP_ID")" "Cannot exec into pods"
    
    echo ""
fi

# =============================================================================
# Summary
# =============================================================================
echo "=============================================="
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "All personas have the expected permissions."
    exit 0
else
    echo -e "${RED}✗ $FAILURES test(s) failed${NC}"
    echo ""
    echo "Review the failed tests above and verify:"
    echo "  1. RBAC roles are correctly applied"
    echo "  2. RoleBindings reference the correct Entra ID groups"
    echo "  3. Users are members of the appropriate groups"
    echo "  4. Group object IDs match in both Entra ID and Kubernetes"
    exit 1
fi
