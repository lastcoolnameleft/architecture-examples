#!/bin/zsh
# =============================================================================
# Cleanup Script for AKS IAM Posture
# =============================================================================
# Removes everything created by setup-demo-accounts.sh and the infra deployment:
#   - Kubernetes RBAC (ClusterRoles, RoleBindings, Roles)
#   - Entra ID demo users
#   - Entra ID groups
#   - AKS infrastructure (Terraform destroy or Azure resource group delete)
#   - Generated demo-accounts-<CLUSTER_NAME>.env file
#
# Prerequisites:
# - Azure CLI logged in with Entra ID admin permissions
# - kubectl configured for the target cluster (if removing RBAC)
#
# Usage:
#   ./cleanup.sh [OPTIONS]
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
CLUSTER_NAME="iam-sandbox-aks"
DOMAIN=""
RESOURCE_GROUP="${RESOURCE_GROUP:-}"   # can be set via env var or --resource-group
INFRA_TOOL="terraform" # "terraform" | "bicep" | "" (skip infra teardown)
NAMESPACE=""           # if set, also remove namespace-scoped RBAC from this namespace
SKIP_CONFIRM=false
SKIP_RBAC=false
SKIP_USERS=false
SKIP_GROUPS=false
SKIP_INFRA=false
SKIP_ENV_FILE=false

# =============================================================================
# Argument parsing
# =============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"; shift 2 ;;
        --domain)
            DOMAIN="$2"; shift 2 ;;
        --resource-group)
            RESOURCE_GROUP="$2"; shift 2 ;;
        --infra-tool)
            INFRA_TOOL="$2"; shift 2 ;;
        --namespace)
            NAMESPACE="$2"; shift 2 ;;
        --skip-rbac)
            SKIP_RBAC=true; shift ;;
        --skip-users)
            SKIP_USERS=true; shift ;;
        --skip-groups)
            SKIP_GROUPS=true; shift ;;
        --skip-infra)
            SKIP_INFRA=true; shift ;;
        --skip-env-file)
            SKIP_ENV_FILE=true; shift ;;
        -y|--yes)
            SKIP_CONFIRM=true; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cluster <name>         Cluster name used during setup (default: iam-sandbox-aks)"
            echo "  --domain <domain>        Entra ID tenant domain (auto-detected if omitted)"
            echo "  --resource-group <rg>    Azure resource group; overrides \$RESOURCE_GROUP env var (required for --infra-tool)"
            echo "  --infra-tool <tool>      Destroy infra: 'terraform' or 'bicep'"
            echo "  --namespace <ns>         Also remove namespace-scoped RBAC from this namespace"
            echo "  --skip-rbac              Skip Kubernetes RBAC removal"
            echo "  --skip-users             Skip Entra ID demo user deletion"
            echo "  --skip-groups            Skip Entra ID group deletion"
            echo "  --skip-infra             Skip infrastructure teardown"
            echo "  --skip-env-file          Skip generated .env file removal"
            echo "  -y, --yes                Skip confirmation prompt"
            echo "  --help                   Show this help message"
            exit 0 ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1 ;;
    esac
done

# =============================================================================
# Resolve domain
# =============================================================================
if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}Getting tenant domain...${NC}"
    DOMAIN=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null | cut -d'@' -f2)
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}Could not determine domain. Please provide --domain.${NC}"
        exit 1
    fi
    echo -e "Using domain: ${GREEN}$DOMAIN${NC}"
fi

# =============================================================================
# Define the same groups and users as setup-demo-accounts.sh
# =============================================================================
typeset -A GROUPS
GROUPS=(
    [InfraOps-L2-Elevated]="Infrastructure Operations Engineers (L2) - Cluster Admin"
    [PlatformSRE-L3-Elevated]="Platform Engineers and SREs (L3) - Cluster Admin"
    [AppSupport-L2-Elevated]="Application Support Engineers (L2) - Namespace Operator"
    [CommandCentre-L1-Elevated]="Command Centre Engineers (L1) - Restricted Operator"
    [CloudDeployment-Elevated]="Cloud Deployment Engineers - Namespace Deployment"
    [ClusterViewer]="Cluster Viewers - Read Only Access (Standing)"
)

USERS_CONFIG=(
    "demo-infraops|Demo InfraOps|InfraOps-L2-Elevated"
    "demo-platformsre|Demo PlatformSRE|PlatformSRE-L3-Elevated"
    "demo-appsupport|Demo AppSupport|AppSupport-L2-Elevated"
    "demo-commandcentre|Demo CommandCentre|CommandCentre-L1-Elevated"
    "demo-clouddeployment|Demo CloudDeployment|CloudDeployment-Elevated"
    "demo-viewer|Demo Viewer|ClusterViewer"
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${REPO_DIR}/demo-accounts-${CLUSTER_NAME}.env"

# =============================================================================
# Summary and confirmation
# =============================================================================
echo ""
echo "=============================================="
echo "AKS IAM Posture - Cleanup"
echo "=============================================="
echo "Cluster Name  : $CLUSTER_NAME"
echo "Domain        : $DOMAIN"
echo "Resource Group: ${RESOURCE_GROUP:-"(not provided)"}"
echo "Infra Tool    : ${INFRA_TOOL:-"(skip infra teardown)"}"
echo ""
echo "Will remove:"
$SKIP_RBAC      || echo "  - Kubernetes ClusterRoles + ClusterRoleBindings (kubectl delete -k rbac/cluster/)"
[ -n "$NAMESPACE" ] && ! $SKIP_RBAC && echo "  - Namespace RBAC in namespace: $NAMESPACE"
$SKIP_USERS     || echo "  - Entra ID demo users (demo-infraops, demo-platformsre, ...)"
$SKIP_GROUPS    || echo "  - Entra ID groups (AKS-${CLUSTER_NAME}-*)"
$SKIP_INFRA     || [ -z "$INFRA_TOOL" ] || echo "  - Infrastructure via $INFRA_TOOL (resource group: $RESOURCE_GROUP)"
$SKIP_ENV_FILE  || [ ! -f "$ENV_FILE" ] || echo "  - Generated env file: $ENV_FILE"
echo "=============================================="
echo ""

if ! $SKIP_CONFIRM; then
    echo -e "${YELLOW}WARNING: This is destructive and cannot be undone.${NC}"
    echo -n "Type 'yes' to continue: "
    read -r confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
    echo ""
fi

ERRORS=0

# =============================================================================
# 1. Kubernetes RBAC
# =============================================================================
if ! $SKIP_RBAC; then
    echo -e "${BLUE}Removing Kubernetes RBAC...${NC}"

    if ! kubectl cluster-info &>/dev/null; then
        echo -e "${YELLOW}  kubectl not configured or cluster unreachable — skipping RBAC removal.${NC}"
    else
        echo -n "  Removing cluster-scoped RBAC... "
        if kubectl delete -k "${REPO_DIR}/rbac/cluster/" --ignore-not-found 2>/dev/null; then
            echo -e "${GREEN}done${NC}"
        else
            echo -e "${RED}failed${NC}"; ((ERRORS++))
        fi

        if [ -n "$NAMESPACE" ]; then
            echo -n "  Removing namespace RBAC from '$NAMESPACE'... "
            if kubectl delete -f "${REPO_DIR}/rbac/namespace/namespace-roles.yaml" \
                              -f "${REPO_DIR}/rbac/namespace/namespace-rolebindings.yaml" \
                              -n "$NAMESPACE" --ignore-not-found 2>/dev/null; then
                echo -e "${GREEN}done${NC}"
            else
                echo -e "${RED}failed${NC}"; ((ERRORS++))
            fi
        fi
    fi
    echo ""
fi

# =============================================================================
# 2. Entra ID demo users
# =============================================================================
if ! $SKIP_USERS; then
    echo -e "${BLUE}Deleting Entra ID demo users...${NC}"

    for user_config in "${USERS_CONFIG[@]}"; do
        username=$(echo "$user_config" | cut -d'|' -f1)
        upn="${username}@${DOMAIN}"
        echo -n "  Deleting user: $upn ... "

        user_id=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null || echo "")
        if [ -z "$user_id" ]; then
            echo -e "${YELLOW}not found${NC}"
        else
            if az ad user delete --id "$user_id" 2>/dev/null; then
                echo -e "${GREEN}deleted${NC}"
            else
                echo -e "${RED}failed${NC}"; ((ERRORS++))
            fi
        fi
    done
    echo ""
fi

# =============================================================================
# 3. Entra ID groups
# =============================================================================
if ! $SKIP_GROUPS; then
    echo -e "${BLUE}Deleting Entra ID groups...${NC}"

    for group_suffix in ${(k)GROUPS}; do
        group_name="AKS-${CLUSTER_NAME}-${group_suffix}"
        echo -n "  Deleting group: $group_name ... "

        group_id=$(az ad group show --group "$group_name" --query id -o tsv 2>/dev/null || echo "")
        if [ -z "$group_id" ]; then
            echo -e "${YELLOW}not found${NC}"
        else
            if az ad group delete --group "$group_id" 2>/dev/null; then
                echo -e "${GREEN}deleted${NC}"
            else
                echo -e "${RED}failed${NC}"; ((ERRORS++))
            fi
        fi
    done
    echo ""
fi

# =============================================================================
# 4. Infrastructure teardown
# =============================================================================
if ! $SKIP_INFRA && [ -n "$INFRA_TOOL" ]; then
    echo -e "${BLUE}Tearing down infrastructure (${INFRA_TOOL})...${NC}"

    case "$INFRA_TOOL" in
        terraform)
            TF_DIR="${REPO_DIR}/infra/terraform"
            if [ ! -f "${TF_DIR}/terraform.tfstate" ]; then
                echo -e "${YELLOW}  No terraform.tfstate found in $TF_DIR — skipping.${NC}"
            else
                # AKS cannot delete node pools while the cluster is stopped — start it first.
                AKS_NAME=$(cd "$TF_DIR" && terraform output -raw aks_cluster_name 2>/dev/null || echo "$CLUSTER_NAME")
                RG="${RESOURCE_GROUP}"

                if [ -n "$AKS_NAME" ] && [ -n "$RG" ]; then
                    POWER_STATE=$(az aks show --name "$AKS_NAME" --resource-group "$RG" \
                        --query "powerState.code" -o tsv 2>/dev/null || echo "")
                    if [ "$POWER_STATE" = "Stopped" ]; then
                        echo -e "${YELLOW}  Cluster '$AKS_NAME' is stopped. Starting it before destroy...${NC}"
                        if az aks start --name "$AKS_NAME" --resource-group "$RG" --no-wait 2>/dev/null; then
                            echo -n "  Waiting for cluster to reach Running state..."
                            az aks wait --name "$AKS_NAME" --resource-group "$RG" \
                                --updated --interval 30 --timeout 600 2>/dev/null && \
                                echo -e " ${GREEN}running${NC}" || echo -e " ${YELLOW}timed out, proceeding anyway${NC}"
                        else
                            echo -e "${RED}  Failed to start cluster. Destroy may fail.${NC}"
                        fi
                    fi
                fi

                echo "  Running terraform destroy in $TF_DIR ..."
                if (cd "$TF_DIR" && terraform destroy -auto-approve); then
                    echo -e "${GREEN}  Terraform destroy complete.${NC}"
                else
                    echo -e "${RED}  Terraform destroy failed.${NC}"; ((ERRORS++))
                fi
            fi
            ;;

        bicep)
            if [ -z "$RESOURCE_GROUP" ]; then
                echo -e "${RED}  --resource-group is required for bicep teardown.${NC}"; ((ERRORS++))
            else
                echo -n "  Deleting resource group '$RESOURCE_GROUP'... "
                if az group delete --name "$RESOURCE_GROUP" --yes --no-wait 2>/dev/null; then
                    echo -e "${GREEN}deletion initiated (async)${NC}"
                else
                    echo -e "${RED}failed${NC}"; ((ERRORS++))
                fi
            fi
            ;;

        *)
            echo -e "${RED}  Unknown infra tool '$INFRA_TOOL'. Use 'terraform' or 'bicep'.${NC}"; ((ERRORS++))
            ;;
    esac
    echo ""
fi

# =============================================================================
# 5. Generated .env file
# =============================================================================
if ! $SKIP_ENV_FILE; then
    if [ -f "$ENV_FILE" ]; then
        echo -n "Removing generated env file: $ENV_FILE ... "
        if rm "$ENV_FILE"; then
            echo -e "${GREEN}removed${NC}"
        else
            echo -e "${RED}failed${NC}"; ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}Env file not found (already removed): $ENV_FILE${NC}"
    fi
    echo ""
fi

# =============================================================================
# Summary
# =============================================================================
echo "=============================================="
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}Cleanup complete. No errors.${NC}"
else
    echo -e "${RED}Cleanup finished with $ERRORS error(s). Review output above.${NC}"
fi
echo "=============================================="
