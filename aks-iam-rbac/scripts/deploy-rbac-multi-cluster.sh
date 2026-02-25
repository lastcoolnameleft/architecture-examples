#!/bin/bash
# =============================================================================
# Multi-Cluster RBAC Deployment Script
# =============================================================================
# This script deploys RBAC configurations to multiple AKS clusters consistently.
# It's designed for Nothing-Shared SaaS model with isolated customer clusters.
#
# Prerequisites:
# - Azure CLI logged in with appropriate permissions
# - kubectl available
# - jq installed
# - RBAC YAML files with group IDs already configured
#
# Usage:
#   ./deploy-rbac-multi-cluster.sh [--clusters <cluster1,cluster2>] [--namespaces <ns1,ns2>]
#
# Note:
#   - Always deploys cluster-level RBAC (ClusterRoles and ClusterRoleBindings)
#   - Namespace-level RBAC only deployed when --namespaces is specified
#
# Examples:
#   ./deploy-rbac-multi-cluster.sh --clusters aks-customer1-prod,aks-customer2-prod --namespaces default,app1
#   ./deploy-rbac-multi-cluster.sh --namespaces default,app1,app2,app3
#   ./deploy-rbac-multi-cluster.sh --clusters iam-sandbox-aks --namespaces default
# =============================================================================

set -e

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RBAC_DIR="$(dirname "$SCRIPT_DIR")/rbac"
CLUSTERS=""
NAMESPACES=""
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clusters)
            CLUSTERS="$2"
            shift 2
            ;;
        --namespaces)
            NAMESPACES="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clusters <list>     Comma-separated list of cluster names"
            echo "  --namespaces <list>   Comma-separated list of application namespaces"
            echo "                        (Required for namespace-level RBAC deployment)"
            echo "  --dry-run            Show what would be done without making changes"
            echo "  --help               Show this help message"
            echo ""
            echo "Note: Cluster-level RBAC is always deployed. Namespace-level RBAC"
            echo "      requires --namespaces parameter."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to log
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Get clusters from Azure if not provided
get_clusters() {
    if [ -z "$CLUSTERS" ]; then
        log "Discovering AKS clusters from Azure subscription..."
        CLUSTERS=$(az aks list --query "[].name" -o tsv | tr '\n' ',' | sed 's/,$//')
        
        if [ -z "$CLUSTERS" ]; then
            log_error "No AKS clusters found in current subscription"
            exit 1
        fi
        
        log "Found clusters: $CLUSTERS"
        echo ""
        read -p "Deploy to all these clusters? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            echo "Aborted."
            exit 0
        fi
    fi
}

# Deploy to a single cluster
deploy_to_cluster() {
    local cluster=$1
    local rg
    
    log "Processing cluster: $cluster"
    
    # Get resource group for cluster
    rg=$(az aks list --query "[?name=='$cluster'].resourceGroup" -o tsv)
    
    if [ -z "$rg" ]; then
        log_error "Could not find resource group for cluster $cluster"
        return 1
    fi
    
    log "  Resource Group: $rg"
    
    # Get credentials
    if [ "$DRY_RUN" = false ]; then
        log "  Getting cluster credentials..."
        az aks get-credentials --resource-group "$rg" --name "$cluster" --overwrite-existing --admin 2>/dev/null || \
        az aks get-credentials --resource-group "$rg" --name "$cluster" --overwrite-existing
    fi
    
    # Apply cluster-wide RBAC
    log "  Applying cluster-wide RBAC..."
    if [ "$DRY_RUN" = true ]; then
        log "    [DRY-RUN] Would apply: kubectl apply -k $RBAC_DIR/cluster/"
    else
        kubectl apply -k "$RBAC_DIR/cluster/" 2>&1 | while read line; do
            echo "    $line"
        done
    fi
    
    # Apply namespace RBAC
    if [ -n "$NAMESPACES" ]; then
        IFS=',' read -ra NS_ARRAY <<< "$NAMESPACES"
        for ns in "${NS_ARRAY[@]}"; do
            log "  Applying namespace RBAC to: $ns"
            
            if [ "$DRY_RUN" = true ]; then
                log "    [DRY-RUN] Would create namespace: $ns"
                log "    [DRY-RUN] Would apply roles to: $ns"
            else
                # Create namespace if not exists
                kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
                
                # Apply roles
                kubectl apply -f "$RBAC_DIR/namespace/namespace-roles.yaml" -n "$ns" 2>&1 | while read line; do
                    echo "    $line"
                done
                
                # Apply bindings
                kubectl apply -f "$RBAC_DIR/namespace/namespace-rolebindings.yaml" -n "$ns" 2>&1 | while read line; do
                    echo "    $line"
                done
            fi
        done
    else
        log_warning "  No namespaces specified, skipping namespace RBAC"
    fi
    
    log_success "Completed: $cluster"
    echo ""
}

# Main execution
main() {
    echo "=============================================="
    echo "AKS Multi-Cluster RBAC Deployment"
    echo "=============================================="
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY-RUN MODE: No changes will be made"
        echo ""
    fi
    
    # Check prerequisites
    log "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Please install az."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if [ ! -d "$RBAC_DIR" ]; then
        log_error "RBAC directory not found: $RBAC_DIR"
        exit 1
    fi
    
    log_success "Prerequisites OK"
    echo ""
    
    # Get clusters
    get_clusters
    
    # Deploy to each cluster
    IFS=',' read -ra CLUSTER_ARRAY <<< "$CLUSTERS"
    TOTAL=${#CLUSTER_ARRAY[@]}
    CURRENT=0
    
    for cluster in "${CLUSTER_ARRAY[@]}"; do
        CURRENT=$((CURRENT + 1))
        echo "=============================================="
        echo "[$CURRENT/$TOTAL] Cluster: $cluster"
        echo "=============================================="
        
        if deploy_to_cluster "$cluster"; then
            log_success "Cluster $cluster completed successfully"
        else
            log_error "Cluster $cluster failed"
        fi
    done
    
    echo "=============================================="
    echo "Deployment Summary"
    echo "=============================================="
    echo "Clusters processed: $TOTAL"
    echo "Namespaces per cluster: $(echo "$NAMESPACES" | tr ',' '\n' | wc -l | tr -d ' ')"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "This was a dry run. Run without --dry-run to apply changes."
    else
        log_success "Deployment complete!"
        echo ""
        echo "Next steps:"
        echo "1. Verify RBAC configuration: scripts/validate-rbac.sh <RG> <CLUSTER> <LAW-NAME>"
        echo "2. Test persona permissions: scripts/validate-persona-permissions.sh <CONFIG-FILE>"
        echo "3. Test with actual Entra ID users (az login as user, then kubectl commands)"
        echo "4. Monitor audit logs in Log Analytics workspace"
    fi
}

main "$@"
