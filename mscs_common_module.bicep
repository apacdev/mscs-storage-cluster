@description('Location for resources to be created. Default is the resource group location.')
param location string = resourceGroup().location

@description('Name of the Log Analytics Workspace.')
param log_space_name string

@description('SKU of the Log Analytics Workspace. Default is PerGB2018.') 
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
  'PerGB2018'
  'Starter'
  'CapacityReservation'
])
param log_space_sku string

@description('Name of the Azure Automation Account.')
param automate_name string

@description('Name of the Azure Storage Account.')
param storage_account_name string

@description('Name of the vnet resource.')
param vnet_name string

param mscs_network_resources_name string
resource vnet_resource 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: vnet_name
  scope: resourceGroup(mscs_network_resources_name)
}
// create resource for Azure Storage Account
resource storage_account_resource 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storage_account_name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: false
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    allowedCopyScope: 'AAD'
    isHnsEnabled: true
    largeFileSharesState: 'Disabled'
    networkAcls: {
        resourceAccessRules: []
        bypass: 'AzureServices, Logging'
        virtualNetworkRules: [
            {
              id: vnet_resource.properties.subnets[0].id
              action: 'Allow'
            }
            {
              id: vnet_resource.properties.subnets[1].id
              action: 'Allow'
          }
        ]
        ipRules: [
          {
            value: '103.241.0.0/16'
            action: 'Allow'
          }
          {
            value: '103.241.62.240'
          }
        ]
        defaultAction: 'Deny'
    }
  }
  dependsOn: [
    vnet_resource
  ]
}

// create resource for Azure Storage Account Blob Service
resource storage_account_blob 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' =  {
  name: '${storage_account_name}/default/dsc-configurations'
  properties: {
    publicAccess: 'Container'
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
  }
  dependsOn: [
    storage_account_resource
  ]
}

// create resource for log analytics workspace
resource log_space_resource 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: log_space_name
  location: location
  properties: {
    sku: {
      name: log_space_sku
    }
  }
  dependsOn: [
    storage_account_resource
  ]
}

// create resource for Azure Automation Account
resource automate_resource 'Microsoft.Automation/automationAccounts@2022-08-08'= {
  name: automate_name
  location: location
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  dependsOn: [
    storage_account_resource, log_space_resource
  ]
}
