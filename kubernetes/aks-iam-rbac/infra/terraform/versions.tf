# =============================================================================
# Provider Version Constraints
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0, < 4.0.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.9.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstate<unique>"
  #   container_name       = "tfstate"
  #   key                  = "aks-iam.tfstate"
  # }
}
