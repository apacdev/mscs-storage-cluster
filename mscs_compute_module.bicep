@description('See https://azure.microsoft.com/en-us/global-infrastructure/locations for valid values.')
param location string = resourceGroup().location

@description('The name of the network resources.')
param mscs_network_resources_name string

@description('The name of the storage resources.')
param mscs_storage_resources_name string

@description('The name of the common resources.')
param mscs_common_resources_name string 

@description('The name of the storage account to use for the VMs.')
param storage_account_name string

@description('The name of the Azure Shared Disk to use for the VMs (Cluster Shared Volume)')
param disk_name string

@description('The name of the admin account for the VMs')
param admin_name string

@description('The password of the admin account for the VMs')
@secure()
param admin_password string

@description('See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes for valid values.')
@allowed([
  'Standard_F4s_v2'
  'standard_E4s_v4'
  'Standard_E4s_v4'
])
param vm_size string

@description('The name of the VM-01 to create (VM-01 is assumed to be a domain-controller throughout this template).')
param vm_01_name string

@description('The name of the VM-02 to create (VM-02 is assumed to be a cluster node).')
param vm_02_name string

@description('The name of the VM-03 to create (VM-03 is assumed to be a cluster node).')
param vm_03_name string

@description('The name of the network interface for VM-01.')
param nic_vm_01_name string

@description('The name of the network interface for VM-02.')
param nic_vm_02_name string

@description('The name of the network interface for VM-03.')
param nic_vm_03_name string

// reference to existing network interface 01
resource nic_vm_01_resource 'Microsoft.Network/networkInterfaces@2022-09-01' existing = {
  name: nic_vm_01_name
  scope: resourceGroup(mscs_network_resources_name)
}

// reference to existing network interface 02
resource nic_vm_02_resource 'Microsoft.Network/networkInterfaces@2022-09-01' existing = {
  name: nic_vm_02_name
  scope: resourceGroup(mscs_network_resources_name)
}

// reference to existing network interface 03
resource nic_vm_03_resource 'Microsoft.Network/networkInterfaces@2022-09-01' existing = {
  name: nic_vm_03_name
  scope: resourceGroup(mscs_network_resources_name)
}

// reference to existing disk
resource disk_resource 'Microsoft.Compute/disks@2022-07-02' existing = {
  name: disk_name
  scope: resourceGroup(mscs_storage_resources_name)
}

// reference to existing storage account
resource stroage_account_resource 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storage_account_name
  scope: resourceGroup(mscs_common_resources_name)
 }

 // create resource for VM-01
resource vm_01_resource 'Microsoft.Compute/virtualMachines@2022-11-01' = {  
  name: vm_01_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic_vm_01_resource.id
        }]
    }
    osProfile: {
      computerName: vm_01_name
      adminUsername: admin_name 
      adminPassword: admin_password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'    
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        diskSizeGB: 128
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stroage_account_resource.properties.primaryEndpoints.blob
      }
    }
  }
    zones: ['1']
    dependsOn: [
      stroage_account_resource
    ]
}

// create resource for VM-02
resource vm_02_resource 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vm_02_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic_vm_02_resource.id
        }
      ]
    }
    osProfile: {
      computerName: vm_02_name
      adminUsername: admin_name 
      adminPassword: admin_password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        diskSizeGB: 128
      }
      dataDisks: [{
        lun: 0
        caching:'None'
        createOption: 'Attach'
        managedDisk: {
          id: disk_resource.id
        }
      }]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stroage_account_resource.properties.primaryEndpoints.blob
      }
    }
  }
    zones: ['2']
    dependsOn: [
      vm_01_resource
      stroage_account_resource
    ]
  }

// create resource for VM-03
resource vm_03_resource 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vm_03_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic_vm_03_resource.id
        }
      ]
    }
    osProfile: {
      computerName: vm_03_name
      adminUsername: admin_name 
      adminPassword: admin_password
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        diskSizeGB: 128
      }
      dataDisks: [{
        lun: 0
        caching: 'None'
        createOption: 'Attach'
        managedDisk: {
          id: disk_resource.id
        }
      }]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: stroage_account_resource.properties.primaryEndpoints.blob
      }
    }
  }
    zones: ['2']
    dependsOn: [
      stroage_account_resource, vm_02_resource
    ]
}
