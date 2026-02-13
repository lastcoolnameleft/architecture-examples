# =============================================================================
# OUTPUTS
# =============================================================================

output "aks_cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_oidc_issuer_url" {
  description = "AKS cluster OIDC issuer URL"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "aks_managed_identity_principal_id" {
  description = "AKS cluster managed identity principal ID"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = local.effective_log_analytics_workspace_id
}

output "kubelet_identity_client_id" {
  description = "Kubelet identity client ID"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
}

output "kubelet_identity_object_id" {
  description = "Kubelet identity object ID"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "node_resource_group" {
  description = "Node resource group name"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "kube_config" {
  description = "Kubernetes configuration for kubectl"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}
