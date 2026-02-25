# =============================================================================
# AKS Cluster Deployment - Nothing-Shared SaaS Model with Azure RBAC Integration
# =============================================================================
# This Terraform configuration deploys an AKS cluster with:
# - Azure RBAC for Kubernetes authorization (Entra ID integration)
# - Disabled local accounts (forces Entra ID authentication)
# - Comprehensive audit logging to Log Analytics
# - Security best practices aligned with enterprise requirements
# =============================================================================

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  dns_prefix                   = var.dns_prefix != null ? var.dns_prefix : var.cluster_name
  log_analytics_workspace_name = var.log_analytics_workspace_name != "" ? var.log_analytics_workspace_name : "law-${var.cluster_name}"
  create_log_analytics         = var.log_analytics_workspace_id == ""

  # Diagnostic log categories for comprehensive audit logging
  diagnostic_log_categories = [
    "kube-apiserver",          # API server logs - critical for RBAC audit
    "kube-audit-admin",        # Admin audit logs - elevated actions
    "kube-controller-manager", # Controller manager logs
    "kube-scheduler",          # Scheduler logs
    "cluster-autoscaler",      # Autoscaler logs
    "guard",                   # Azure AD authentication logs
  ]
}

# =============================================================================
# LOG ANALYTICS WORKSPACE (conditional creation)
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  count = local.create_log_analytics ? 1 : 0

  name                = local.log_analytics_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_retention_in_days

  tags = var.tags
}

locals {
  effective_log_analytics_workspace_id = local.create_log_analytics ? azurerm_log_analytics_workspace.main[0].id : var.log_analytics_workspace_id
}

# =============================================================================
# AKS MANAGED CLUSTER
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version

  sku_tier = "Standard" # Standard tier for SLA and production workloads

  # Disable local accounts to enforce Entra ID authentication
  local_account_disabled = var.disable_local_accounts

  # Private cluster configuration
  private_cluster_enabled             = var.enable_private_cluster
  private_dns_zone_id                 = var.enable_private_cluster ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = false

  # Disk encryption
  disk_encryption_set_id = var.disk_encryption_set_id != "" ? var.disk_encryption_set_id : null

  # Node resource group restriction
  node_resource_group = "${var.cluster_name}-nodes"

  # ==========================================================================
  # AAD/Entra ID Integration with Azure RBAC - CRITICAL FOR IAM POSTURE
  # ==========================================================================
  azure_active_directory_role_based_access_control {
    managed                = true # Required for AKS-managed Entra integration
    azure_rbac_enabled     = var.enable_azure_rbac
    admin_group_object_ids = var.cluster_admin_group_object_ids
  }

  # ==========================================================================
  # Identity Configuration
  # ==========================================================================
  identity {
    type = "SystemAssigned"
  }

  # ==========================================================================
  # Network Configuration
  # ==========================================================================
  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  # ==========================================================================
  # System Node Pool
  # ==========================================================================
  default_node_pool {
    name                         = "systempool"
    node_count                   = var.system_node_count
    vm_size                      = var.system_node_vm_size
    enable_auto_scaling          = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    zones                        = length(var.availability_zones) > 0 ? var.availability_zones : null
    os_disk_size_gb              = 100
    os_disk_type                 = "Ephemeral"
    os_sku                       = "AzureLinux"
    vnet_subnet_id               = var.vnet_subnet_id != "" ? var.vnet_subnet_id : null
    max_pods                     = 50
    only_critical_addons_enabled = true
    enable_host_encryption       = true
    enable_node_public_ip        = false

    upgrade_settings {
      max_surge = "33%"
    }

    temporary_name_for_rotation = "systmp"
  }

  # ==========================================================================
  # Security Profile
  # ==========================================================================
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 24
  workload_identity_enabled    = true
  oidc_issuer_enabled          = true

  # ==========================================================================
  # Microsoft Defender
  # ==========================================================================
  dynamic "microsoft_defender" {
    for_each = var.enable_azure_defender ? [1] : []
    content {
      log_analytics_workspace_id = local.effective_log_analytics_workspace_id
    }
  }

  # ==========================================================================
  # OMS Agent for Monitoring
  # ==========================================================================
  oms_agent {
    log_analytics_workspace_id      = local.effective_log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  # ==========================================================================
  # Azure Policy
  # ==========================================================================
  azure_policy_enabled = var.enable_azure_policy

  # ==========================================================================
  # Key Vault Secrets Provider
  # ==========================================================================
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # ==========================================================================
  # Storage Profile
  # ==========================================================================
  storage_profile {
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
    blob_driver_enabled         = false
  }

  # ==========================================================================
  # Auto Upgrade Profile
  # ==========================================================================
  automatic_channel_upgrade = "stable"
  node_os_channel_upgrade   = "NodeImage"

  tags = var.tags
}

# =============================================================================
# USER NODE POOL
# =============================================================================

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                   = "userpool"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.main.id
  mode                   = "User"
  node_count             = var.user_node_count
  vm_size                = var.user_node_vm_size
  enable_auto_scaling    = true
  min_count              = var.user_node_min_count
  max_count              = var.user_node_max_count
  zones                  = length(var.availability_zones) > 0 ? var.availability_zones : null
  os_disk_size_gb        = 100
  os_disk_type           = "Ephemeral"
  os_sku                 = "AzureLinux"
  vnet_subnet_id         = var.vnet_subnet_id != "" ? var.vnet_subnet_id : null
  max_pods               = 50
  enable_host_encryption = true
  enable_node_public_ip  = false

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}

# =============================================================================
# DIAGNOSTIC SETTINGS FOR COMPREHENSIVE AUDIT LOGGING
# =============================================================================

resource "azapi_resource" "aks_diagnostics" {
  type      = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name      = "${var.cluster_name}-diagnostics"
  parent_id = azurerm_kubernetes_cluster.main.id

  body = {
    properties = {
      workspaceId                = local.effective_log_analytics_workspace_id
      logAnalyticsDestinationType = "Dedicated"
      logs = [
        for category in local.diagnostic_log_categories : {
          category = category
          enabled  = true
        }
      ]
      metrics = [
        {
          category = "AllMetrics"
          enabled  = true
        }
      ]
    }
  }
}
