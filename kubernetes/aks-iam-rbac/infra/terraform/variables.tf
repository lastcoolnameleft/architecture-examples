# =============================================================================
# AKS Cluster Deployment Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster Identity
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the AKS cluster. Should follow naming convention: aks-<customer>-<environment>-<region>"
  type        = string
}

variable "location" {
  description = "Location for all resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Leave empty for latest stable."
  type        = string
  default     = null
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "saas-customer-cluster"
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vnet_subnet_id" {
  description = "Resource ID of the subnet for AKS nodes. Required for production deployments."
  type        = string
  default     = ""
}

variable "network_plugin" {
  description = "Network plugin to use: azure or kubenet"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be 'azure' or 'kubenet'."
  }
}

variable "network_policy" {
  description = "Network policy to use: azure, calico, or cilium"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "Network policy must be 'azure', 'calico', or 'cilium'."
  }
}

variable "service_cidr" {
  description = "Service CIDR for Kubernetes services"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP (must be within service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

# -----------------------------------------------------------------------------
# Node Pool Configuration
# -----------------------------------------------------------------------------

variable "system_node_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_DS4_v2"
}

variable "system_node_count" {
  description = "Initial node count for system pool"
  type        = number
  default     = 3
}

variable "system_node_min_count" {
  description = "Minimum node count for system pool autoscaling"
  type        = number
  default     = 3
}

variable "system_node_max_count" {
  description = "Maximum node count for system pool autoscaling"
  type        = number
  default     = 5
}

variable "user_node_vm_size" {
  description = "VM size for the user/application node pool"
  type        = string
  default     = "Standard_DS4_v2"
}

variable "user_node_count" {
  description = "Initial node count for user pool"
  type        = number
  default     = 3
}

variable "user_node_min_count" {
  description = "Minimum node count for user pool autoscaling"
  type        = number
  default     = 3
}

variable "user_node_max_count" {
  description = "Maximum node count for user pool autoscaling"
  type        = number
  default     = 10
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["1", "2", "3"]
}

# -----------------------------------------------------------------------------
# Identity & RBAC Configuration
# -----------------------------------------------------------------------------

variable "cluster_admin_group_object_ids" {
  description = "Object IDs of Entra ID groups for cluster admin access (elevated via PIM)"
  type        = list(string)
  default     = []
}

variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

variable "disable_local_accounts" {
  description = "Disable local accounts (recommended for security)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Monitoring & Logging Configuration
# -----------------------------------------------------------------------------

variable "log_analytics_workspace_id" {
  description = "Resource ID of existing Log Analytics workspace. If empty, a new one will be created."
  type        = string
  default     = ""
}

variable "log_analytics_workspace_name" {
  description = "Log Analytics workspace name (used if creating new workspace)"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_sku" {
  description = "Log Analytics workspace SKU"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "PerGB2018", "PerNode", "Premium", "Standalone", "Standard"], var.log_analytics_workspace_sku)
    error_message = "Invalid Log Analytics workspace SKU."
  }
}

variable "log_retention_in_days" {
  description = "Log retention in days"
  type        = number
  default     = 90
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "enable_azure_defender" {
  description = "Enable Azure Defender for Kubernetes"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for Kubernetes"
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "Resource ID of disk encryption set (for encryption at rest)"
  type        = string
  default     = ""
}

variable "enable_private_cluster" {
  description = "Enable private cluster (API server not publicly accessible)"
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Private DNS Zone resource ID (required if enable_private_cluster is true)"
  type        = string
  default     = ""
}
