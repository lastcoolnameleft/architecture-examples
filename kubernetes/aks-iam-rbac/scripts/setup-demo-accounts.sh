#!/bin/zsh
# =============================================================================
# Demo Account Setup Script for AKS IAM Posture
# =============================================================================
# This script creates Entra ID groups and demo users for each persona.
# Run this script with an account that has Entra ID admin permissions.
#
# Prerequisites:
# - Azure CLI logged in with Entra ID admin permissions
# - Permissions to create groups and users in Entra ID
#
# Usage:
#   ./setup-demo-accounts.sh [--domain <your-tenant-domain>]
# =============================================================================

set -e

# Configuration
CLUSTER_NAME="iam-sandbox-aks"
DOMAIN=""
PASSWORD="<CHANGE THIS>"  # Change this for production!

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --domain <domain>    Your Entra ID tenant domain (e.g., contoso.onmicrosoft.com)"
            echo "  --cluster <name>     Cluster name for group naming (default: iam-sandbox-aks)"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get domain if not provided
if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}Getting tenant domain...${NC}"
    DOMAIN=$(az ad signed-in-user show --query userPrincipalName -o tsv | cut -d'@' -f2)
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}Could not determine domain. Please provide --domain parameter.${NC}"
        exit 1
    fi
    echo -e "Using domain: ${GREEN}$DOMAIN${NC}"
fi

echo ""
echo "=============================================="
echo "AKS IAM Demo Account Setup"
echo "=============================================="
echo "Cluster Name: $CLUSTER_NAME"
echo "Domain: $DOMAIN"
echo "=============================================="
echo ""

# =============================================================================
# Define Groups
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

# =============================================================================
# Define Users (username:displayname:group)
# =============================================================================
USERS_CONFIG=(
    "demo-infraops|Demo InfraOps|InfraOps-L2-Elevated"
    "demo-platformsre|Demo PlatformSRE|PlatformSRE-L3-Elevated"
    "demo-appsupport|Demo AppSupport|AppSupport-L2-Elevated"
    "demo-commandcentre|Demo CommandCentre|CommandCentre-L1-Elevated"
    "demo-clouddeployment|Demo CloudDeployment|CloudDeployment-Elevated"
    "demo-viewer|Demo Viewer|ClusterViewer"
)

# Store group IDs
typeset -A GROUP_IDS

# =============================================================================
# Create Groups
# =============================================================================
echo -e "${BLUE}Creating Entra ID Groups...${NC}"
echo ""

for group_suffix in ${(k)GROUPS}; do
    group_name="AKS-${CLUSTER_NAME}-${group_suffix}"
    group_desc="${GROUPS[$group_suffix]}"
    
    echo -n "  Creating group: $group_name ... "
    
    # Check if group already exists
    existing_id=$(az ad group show --group "$group_name" --query id -o tsv 2>/dev/null || echo "")
    
    if [ -n "$existing_id" ]; then
        echo -e "${YELLOW}already exists${NC}"
        GROUP_IDS[$group_suffix]=$existing_id
    else
        # Create the group
        new_id=$(az ad group create \
            --display-name "$group_name" \
            --mail-nickname "${group_name//[^a-zA-Z0-9]/-}" \
            --description "$group_desc" \
            --query id -o tsv 2>/dev/null)
        
        if [ -n "$new_id" ]; then
            echo -e "${GREEN}created${NC}"
            GROUP_IDS[$group_suffix]=$new_id
        else
            echo -e "${RED}failed${NC}"
        fi
    fi
done

echo ""

# =============================================================================
# Create Demo Users and Add to Groups
# =============================================================================
echo -e "${BLUE}Creating Demo Users...${NC}"
echo ""

typeset -A USER_IDS

for user_config in "${USERS_CONFIG[@]}"; do
    # Parse the config
    username=$(echo "$user_config" | cut -d'|' -f1)
    display_name=$(echo "$user_config" | cut -d'|' -f2)
    group_suffix=$(echo "$user_config" | cut -d'|' -f3)
    upn="${username}@${DOMAIN}"
    
    echo -n "  Creating user: $upn ... "
    
    # Check if user already exists
    existing_id=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null || echo "")
    
    if [ -n "$existing_id" ]; then
        echo -e "${YELLOW}already exists${NC}"
        USER_IDS[$username]=$existing_id
    else
        # Create the user
        new_id=$(az ad user create \
            --display-name "$display_name" \
            --user-principal-name "$upn" \
            --password "$PASSWORD" \
            --force-change-password-next-sign-in false \
            --query id -o tsv 2>/dev/null)
        
        if [ -n "$new_id" ]; then
            echo -e "${GREEN}created${NC}"
            USER_IDS[$username]=$new_id
        else
            echo -e "${RED}failed${NC}"
        fi
    fi
done

echo ""

# =============================================================================
# Add Users to Groups
# =============================================================================
echo -e "${BLUE}Adding Users to Groups...${NC}"
echo ""

for user_config in "${USERS_CONFIG[@]}"; do
    username=$(echo "$user_config" | cut -d'|' -f1)
    group_suffix=$(echo "$user_config" | cut -d'|' -f3)
    
    user_id="${USER_IDS[$username]}"
    group_id="${GROUP_IDS[$group_suffix]}"
    group_name="AKS-${CLUSTER_NAME}-${group_suffix}"
    
    if [ -n "$user_id" ] && [ -n "$group_id" ]; then
        echo -n "  Adding $username to $group_name ... "
        
        # Check if already a member
        is_member=$(az ad group member check --group "$group_id" --member-id "$user_id" --query value -o tsv 2>/dev/null || echo "false")
        
        if [ "$is_member" = "true" ]; then
            echo -e "${YELLOW}already member${NC}"
        else
            az ad group member add --group "$group_id" --member-id "$user_id" 2>/dev/null && \
                echo -e "${GREEN}added${NC}" || echo -e "${RED}failed${NC}"
        fi
    fi
done

echo ""

# =============================================================================
# Output Summary
# =============================================================================

echo "=============================================="
echo "Demo Account Setup Complete"
echo "=============================================="
echo ""
echo -e "${GREEN}Groups Created:${NC}"
echo ""
printf "%-50s %s\n" "GROUP NAME" "OBJECT ID"
printf "%-50s %s\n" "----------" "---------"
for group_suffix in ${(k)GROUP_IDS}; do
    group_name="AKS-${CLUSTER_NAME}-${group_suffix}"
    printf "%-50s %s\n" "$group_name" "${GROUP_IDS[$group_suffix]}"
done

echo ""
echo -e "${GREEN}Demo Users Created:${NC}"
echo ""
printf "%-50s %-25s %s\n" "USER PRINCIPAL NAME" "PERSONA" "PASSWORD"
printf "%-50s %-25s %s\n" "-------------------" "-------" "--------"
for user_config in "${USERS_CONFIG[@]}"; do
    username=$(echo "$user_config" | cut -d'|' -f1)
    group_suffix=$(echo "$user_config" | cut -d'|' -f3)
    upn="${username}@${DOMAIN}"
    printf "%-50s %-25s %s\n" "$upn" "$group_suffix" "$PASSWORD"
done

echo ""
echo "=============================================="
echo "Group Object IDs for Bicep Parameters"
echo "=============================================="
echo ""
echo "Copy these values to your main.bicepparam file:"
echo ""
echo "param clusterAdminGroupObjectIds = ["
echo "  '${GROUP_IDS[InfraOps-L2-Elevated]}'   // InfraOps L2"
echo "  '${GROUP_IDS[PlatformSRE-L3-Elevated]}'   // Platform SRE L3"
echo "]"
echo ""

# Save to file for easy reference
OUTPUT_FILE="../demo-accounts-${CLUSTER_NAME}.env"
cat > "$OUTPUT_FILE" << EOF
# =============================================================================
# Demo Account Configuration for ${CLUSTER_NAME}
# Generated: $(date)
# =============================================================================

# Cluster Configuration
CLUSTER_NAME="${CLUSTER_NAME}"
DOMAIN="${DOMAIN}"

# =============================================================================
# Group Object IDs
# =============================================================================
INFRA_OPS_L2_GROUP_ID="${GROUP_IDS[InfraOps-L2-Elevated]}"
PLATFORM_SRE_L3_GROUP_ID="${GROUP_IDS[PlatformSRE-L3-Elevated]}"
APP_SUPPORT_L2_GROUP_ID="${GROUP_IDS[AppSupport-L2-Elevated]}"
COMMAND_CENTRE_L1_GROUP_ID="${GROUP_IDS[CommandCentre-L1-Elevated]}"
CLOUD_DEPLOYMENT_GROUP_ID="${GROUP_IDS[CloudDeployment-Elevated]}"
CLUSTER_VIEWER_GROUP_ID="${GROUP_IDS[ClusterViewer]}"

# =============================================================================
# Demo User Credentials
# =============================================================================
# WARNING: Change these passwords before any real use!

DEMO_INFRAOPS_UPN="demo-infraops@${DOMAIN}"
DEMO_PLATFORMSRE_UPN="demo-platformsre@${DOMAIN}"
DEMO_APPSUPPORT_UPN="demo-appsupport@${DOMAIN}"
DEMO_COMMANDCENTRE_UPN="demo-commandcentre@${DOMAIN}"
DEMO_CLOUDDEPLOYMENT_UPN="demo-clouddeployment@${DOMAIN}"
DEMO_VIEWER_UPN="demo-viewer@${DOMAIN}"

DEMO_PASSWORD="${PASSWORD}"

# =============================================================================
# Bicep Parameter Values
# =============================================================================
# Copy this to main.bicepparam:

# param clusterAdminGroupObjectIds = [
#   '${GROUP_IDS[InfraOps-L2-Elevated]}'
#   '${GROUP_IDS[PlatformSRE-L3-Elevated]}'
# ]
EOF

echo -e "${GREEN}Configuration saved to: demo-accounts-${CLUSTER_NAME}.env${NC}"
echo ""
echo "=============================================="
echo "Next Steps"
echo "=============================================="
echo ""
echo "1. Update infra/main.bicepparam with the group IDs above"
echo ""
echo "2. Update RBAC YAML files with group IDs:"
echo "   - rbac/cluster/cluster-roles.yaml"
echo "   - rbac/namespace/namespace-rolebindings.yaml"
echo ""
echo "3. Deploy the AKS cluster:"
echo "   az deployment group create -g <RG> -f infra/main.bicep -p infra/main.bicepparam"
echo ""
echo "4. Apply RBAC manifests:"
echo "   kubectl apply -k rbac/cluster/"
echo ""
echo "5. Test each persona by logging in as the demo user:"
echo "   az login --username demo-infraops@${DOMAIN}"
echo ""
