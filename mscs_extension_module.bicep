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

param vm_01_role string
param vm_02_role string
param vm_03_role string

param vm_01_name string
param vm_02_name string
param vm_03_name string

param iipv4_01_address string
param iipv4_02_address string
param iipv4_03_address string

resource vm_01_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_01_name
 }

 resource vm_02_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_02_name
 }

 resource vm_03_resource 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vm_03_name
 }

 // define array variable for vm ip map
var vm_ip_map = [
    {
      vmName: vm_01_name
      vmIp: iipv4_01_address
    }
    {
      vmName: vm_02_name
      vmIp: iipv4_02_address
    }
    {
      vmName: vm_03_name
      vmIp: iipv4_03_address
}]

 
resource vm_01_cse 'Microsoft.Compute/VirtualMachines/extensions@2022-11-01' = {
  parent: vm_01_resource
  name: 'cse_dc_extension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    settings: {
      fileUris: ['https://raw.githubusercontent.com/ms-apac-csu/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -VmRole ${vm_01_role} -AdminName ${admin_name} -AdminPassword ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -VmIpMap ${vm_ip_map}'
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
      fileUris: ['https://raw.githubusercontent.com/ms-apac-csu/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -VmRole ${vm_02_role} -AdminName ${admin_name} -AdminPassword ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -VmIpMap ${vm_ip_map}'
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
      fileUris: ['https://raw.githubusercontent.com/ms-apac-csu/mscs-storage-cluster/main/extensions/Install-VmFeatures.ps1']
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Install-VmFeatures.ps1 -VmRole ${vm_03_role} -AdminName ${admin_name} -AdminPassword ${admin_password} -DomainName ${domain_name} -DomainNetBiosName ${domain_netbios_name} -DomainServerIpAddress ${domain_server_ip} -VmIpMap ${vm_ip_map}'
    }
  }
}
