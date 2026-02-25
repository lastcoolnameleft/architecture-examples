// =============================================================================
// AKS Cluster Deployment - Nothing-Shared SaaS Model with Azure RBAC Integration
// =============================================================================
// This Bicep template deploys an AKS cluster with:
// - Azure RBAC for Kubernetes authorization (Entra ID integration)
// - Disabled local accounts (forces Entra ID authentication)
// - Comprehensive audit logging to Log Analytics
// - Security best practices aligned with enterprise requirements
// =============================================================================

targetScope = 'resourceGroup'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Name of the AKS cluster. Should follow naming convention: aks-<customer>-<environment>-<region>')
param clusterName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Kubernetes version. Leave empty for latest stable.')
param kubernetesVersion string = ''

@description('DNS prefix for the cluster')
param dnsPrefix string = clusterName

@description('Tags to apply to all resources')
param tags object = {
  Environment: 'production'
  ManagedBy: 'bicep'
  Purpose: 'saas-customer-cluster'
}

// -----------------------------------------------------------------------------
// Network Configuration
// -----------------------------------------------------------------------------

@description('Resource ID of the subnet for AKS nodes. Required for production deployments.')
param vnetSubnetResourceId string = ''

@description('Network plugin to use: azure or kubenet')
@allowed(['azure', 'kubenet'])
param networkPlugin string = 'azure'

@description('Network policy to use: azure, calico, or cilium')
@allowed(['azure', 'calico', 'cilium'])
param networkPolicy string = 'azure'

@description('Service CIDR for Kubernetes services')
param serviceCidr string = '10.0.0.0/16'

@description('DNS service IP (must be within serviceCidr)')
param dnsServiceIP string = '10.0.0.10'

// -----------------------------------------------------------------------------
// Node Pool Configuration
// -----------------------------------------------------------------------------

@description('VM size for the system node pool')
param systemNodeVmSize string = 'Standard_DS4_v2'

@description('Initial node count for system pool')
param systemNodeCount int = 3

@description('Minimum node count for system pool autoscaling')
param systemNodeMinCount int = 3

@description('Maximum node count for system pool autoscaling')
param systemNodeMaxCount int = 5

@description('VM size for the user/application node pool')
param userNodeVmSize string = 'Standard_DS4_v2'

@description('Initial node count for user pool')
param userNodeCount int = 3

@description('Minimum node count for user pool autoscaling')
param userNodeMinCount int = 3

@description('Maximum node count for user pool autoscaling')
param userNodeMaxCount int = 10

@description('Availability zones to use (1, 2, 3)')
param availabilityZones array = ['1', '2', '3']

// -----------------------------------------------------------------------------
// Identity & RBAC Configuration
// -----------------------------------------------------------------------------

@description('Object IDs of Entra ID groups for cluster admin access (elevated via PIM)')
param clusterAdminGroupObjectIds array = []

@description('Enable Azure RBAC for Kubernetes authorization')
param enableAzureRBAC bool = true

@description('Disable local accounts (recommended for security)')
param disableLocalAccounts bool = true

// -----------------------------------------------------------------------------
// Monitoring & Logging Configuration
// -----------------------------------------------------------------------------

@description('Resource ID of existing Log Analytics workspace. If empty, a new one will be created.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Log Analytics workspace name (used if creating new workspace)')
param logAnalyticsWorkspaceName string = 'law-${clusterName}'

@description('Log Analytics workspace SKU')
@allowed(['Free', 'PerGB2018', 'PerNode', 'Premium', 'Standalone', 'Standard'])
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Log retention in days')
param logRetentionInDays int = 90

// -----------------------------------------------------------------------------
// Security Configuration
// -----------------------------------------------------------------------------

@description('Enable Azure Defender for Kubernetes')
param enableAzureDefender bool = true

@description('Enable Azure Policy for Kubernetes')
param enableAzurePolicy bool = true

@description('Resource ID of disk encryption set (for encryption at rest)')
param diskEncryptionSetResourceId string = ''

@description('Enable private cluster (API server not publicly accessible)')
param enablePrivateCluster bool = false

@description('Private DNS Zone resource ID (required if enablePrivateCluster is true)')
param privateDNSZone string = ''

// =============================================================================
// VARIABLES
// =============================================================================

var createLogAnalyticsWorkspace = empty(logAnalyticsWorkspaceResourceId)
var effectiveLogAnalyticsWorkspaceId = createLogAnalyticsWorkspace ? logAnalytics.id : logAnalyticsWorkspaceResourceId

// Define diagnostic log categories for comprehensive audit logging
var diagnosticLogCategories = [
  'kube-apiserver'           // API server logs - critical for RBAC audit
  'kube-audit'               // Kubernetes audit logs - who did what
  'kube-audit-admin'         // Admin audit logs - elevated actions
  'kube-controller-manager'  // Controller manager logs
  'kube-scheduler'           // Scheduler logs
  'cluster-autoscaler'       // Autoscaler logs
  'guard'                    // Azure AD authentication logs
]

// =============================================================================
// RESOURCES
// =============================================================================

// -----------------------------------------------------------------------------
// Log Analytics Workspace (conditional creation)
// -----------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (createLogAnalyticsWorkspace) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// -----------------------------------------------------------------------------
// AKS Managed Cluster
// -----------------------------------------------------------------------------
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-02-preview' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: 'Standard' // Standard tier for SLA and production workloads
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    
    // ==========================================================================
    // AAD/Entra ID Integration with Azure RBAC - CRITICAL FOR IAM POSTURE
    // ==========================================================================
    aadProfile: {
      managed: true                          // Use managed AAD integration
      enableAzureRBAC: enableAzureRBAC       // Enable Azure RBAC for K8s authorization
      adminGroupObjectIDs: clusterAdminGroupObjectIds // Admin groups (elevated via PIM)
    }
    
    // Disable local accounts to enforce Entra ID authentication
    disableLocalAccounts: disableLocalAccounts
    
    // ==========================================================================
    // Network Configuration
    // ==========================================================================
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      networkDataplane: networkPlugin == 'azure' ? 'azure' : null
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    
    // ==========================================================================
    // API Server Access Configuration
    // ==========================================================================
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
      privateDNSZone: enablePrivateCluster ? privateDNSZone : null
      enablePrivateClusterPublicFQDN: false
    }
    
    // ==========================================================================
    // Security Profile
    // ==========================================================================
    securityProfile: {
      defender: enableAzureDefender ? {
        securityMonitoring: {
          enabled: true
        }
        logAnalyticsWorkspaceResourceId: effectiveLogAnalyticsWorkspaceId
      } : null
      imageCleaner: {
        enabled: true
        intervalHours: 24
      }
      workloadIdentity: {
        enabled: true
      }
    }
    
    // Enable OIDC issuer for workload identity
    oidcIssuerProfile: {
      enabled: true
    }
    
    // ==========================================================================
    // Add-ons Profile
    // ==========================================================================
    addonProfiles: {
      // OMS Agent for monitoring
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: effectiveLogAnalyticsWorkspaceId
          useAADAuth: 'true'
        }
      }
      // Azure Policy for governance
      azurepolicy: {
        enabled: enableAzurePolicy
        config: {
          version: 'v2'
        }
      }
      // Azure KeyVault Secrets Provider
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
    
    // ==========================================================================
    // Agent Pool Profiles
    // ==========================================================================
    agentPoolProfiles: [
      // System node pool - for system components
      {
        name: 'systempool'
        mode: 'System'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        enableAutoScaling: true
        minCount: systemNodeMinCount
        maxCount: systemNodeMaxCount
        availabilityZones: !empty(availabilityZones) ? availabilityZones : null
        osDiskSizeGB: 100
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: !empty(vnetSubnetResourceId) ? vnetSubnetResourceId : null
        maxPods: 50
        nodeTaints: ['CriticalAddonsOnly=true:NoSchedule']
        enableEncryptionAtHost: true
        enableFIPS: false
        enableNodePublicIP: false
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
      // User node pool - for application workloads
      {
        name: 'userpool'
        mode: 'User'
        count: userNodeCount
        vmSize: userNodeVmSize
        enableAutoScaling: true
        minCount: userNodeMinCount
        maxCount: userNodeMaxCount
        availabilityZones: !empty(availabilityZones) ? availabilityZones : null
        osDiskSizeGB: 100
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: !empty(vnetSubnetResourceId) ? vnetSubnetResourceId : null
        maxPods: 50
        enableEncryptionAtHost: true
        enableFIPS: false
        enableNodePublicIP: false
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    
    // ==========================================================================
    // Disk Encryption (if provided)
    // ==========================================================================
    diskEncryptionSetID: !empty(diskEncryptionSetResourceId) ? diskEncryptionSetResourceId : null
    
    // ==========================================================================
    // Storage Profile
    // ==========================================================================
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
      blobCSIDriver: {
        enabled: false // Enable if blob storage is needed
      }
    }
    
    // ==========================================================================
    // Auto Upgrade Profile
    // ==========================================================================
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    
    // ==========================================================================
    // Node Resource Group Profile
    // ==========================================================================
    nodeResourceGroupProfile: {
      restrictionLevel: 'ReadOnly' // Prevent manual changes to node resources
    }
  }
}

// -----------------------------------------------------------------------------
// Diagnostic Settings for Comprehensive Audit Logging
// -----------------------------------------------------------------------------
resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${clusterName}-diagnostics'
  scope: aksCluster
  properties: {
    workspaceId: effectiveLogAnalyticsWorkspaceId
    logs: [for category in diagnosticLogCategories: {
      category: category
      enabled: true
      // Note: Retention is managed at the Log Analytics workspace level, not diagnostic settings
    }]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('AKS cluster resource ID')
output aksClusterResourceId string = aksCluster.id

@description('AKS cluster name')
output aksClusterName string = aksCluster.name

@description('AKS cluster FQDN')
output aksClusterFqdn string = aksCluster.properties.fqdn

@description('AKS cluster OIDC issuer URL')
output aksOidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL

@description('AKS cluster managed identity principal ID')
output aksManagedIdentityPrincipalId string = aksCluster.identity.principalId

@description('Log Analytics workspace resource ID')
output logAnalyticsWorkspaceId string = effectiveLogAnalyticsWorkspaceId

@description('Kubelet identity client ID')
output kubeletIdentityClientId string = aksCluster.properties.identityProfile.kubeletidentity.clientId

@description('Kubelet identity object ID')
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId

@description('Node resource group name')
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup
