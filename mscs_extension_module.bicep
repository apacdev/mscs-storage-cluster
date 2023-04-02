// ************************************************************************************************
// * Parameters
// ************************************************************************************************

@description('Admin Username for the Virtual Machine.')
param admin_name string

@description('Admin Password for the Virtual Machine.')
@maxLength(18)
@secure()
param admin_password string

param location string
param domain_name string
param domain_netbios_name string
param domain_server_ip string

param vm_01_name string
param vm_02_name string
param vm_03_name string

param vm_01_role string = 'ad-domain'
param vm_02_role string = 'cluster-node'
param vm_03_role string = 'cluster-node'

param storage_account_name string
param mscs_common_resources_name string

param cluster_name string
param cluster_ip string
param cluster_role_ip string
param cluster_network_name string
param cluster_probe_port string

 resource storage_account_resource 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storage_account_name
  scope: resourceGroup(mscs_common_resources_name)
}


var config_variables  = {
  admin_name: admin_name
  admin_password: admin_password
  domain_name: domain_name 
  domain_netbios_name: domain_netbios_name
  domain_server_ip: domain_server_ip
  storage_account_name: storage_account_resource.name
  storage_account_key: storage_account_resource.listKeys().keys[0].value
  cluster_name: cluster_name 
  cluster_ip: cluster_ip
  cluster_role_ip: cluster_role_ip
  cluster_network_name: cluster_network_name
  cluster_probe_port: cluster_probe_port
}

var vm_parameters_json = json(string(config_variables))

resource vm_01_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_01_name
}

resource vm_02_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_02_name
}

resource vm_03_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_03_name
}

resource vm_01_cse 'Microsoft.Compute/VirtualMachines/extensions@2022-11-01' = {
  parent: vm_01_resource
  name: 'cse_dc_extension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    settings: {
      fileUris: ['https://raw.githubusercontent.com/apacdev/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
//      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -ResourceGroupName ${resource_group_name} -VmName ${vm_01_name} -VmRole ${vm_01_role} -AdminName ${admin_name} -Secret ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -NodeList ${nodeList} -SaName ${saname} -SaKey ${sakey} -ClusterName ${cluster_name} -ClusterIp ${cluster_ip}'
        commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -Role ${vm_01_role} -VmParametersJson ${vm_parameters_json}'
    }
  }
}

resource vm_02_cse 'Microsoft.Compute/VirtualMachines/extensions@2022-11-01' = {
  parent: vm_02_resource
  name: 'cse_fs_extension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: ['https://raw.githubusercontent.com/apacdev/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
//      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -ResourceGroupName ${resource_group_name} -VmName ${vm_02_name} -VmRole ${vm_02_role} -AdminName ${admin_name} -Secret ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -NodeList ${nodeList} -SaName ${saname} -SaKey ${sakey} -ClusterName ${cluster_name} -ClusterIp ${cluster_ip}'
        commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -Role ${vm_02_role} -VmParametersJson ${vm_parameters_json}'
    }
  }
}

resource vm_03_cse 'Microsoft.Compute/VirtualMachines/extensions@2022-11-01' = {
  parent: vm_03_resource
  name: 'cse_fs_extension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: ['https://raw.githubusercontent.com/apacdev/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
//      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -ResourceGroupName ${resource_group_name} -VmName ${vm_03_name} -VmRole ${vm_03_role} -AdminName ${admin_name} -Secret ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -NodeList ${nodeList} -SaName ${saname} -SaKey ${sakey} -ClusterName ${cluster_name} -ClusterIp ${cluster_ip}'
        commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -Role ${vm_03_role} -VmParametersJson ${vm_parameters_json}'
    }
  }
}
