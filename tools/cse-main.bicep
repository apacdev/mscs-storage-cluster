targetScope = 'subscription'

@description('Admin Username for the Virtual Machine and Ad Domain.')
param admin_name string = 'pashim'

@description('Admin Password for the Virtual Machine and Ad Domain.')
@maxLength(18)
@secure()
param admin_password string


@description('Name of the VM-01.')
param vm_01_name string = 'mscswvm-01'

@description('Name of the VM-02.')
param vm_02_name string = 'mscswvm-02'

@description('Name of the VM-03.')
param vm_03_name string = 'mscswvm-03'

@description('Role of the VM-01.')
param vm_01_role string = 'ad-domain'

@description('Role of the VM-02.')
param vm_02_role string = 'cluster-node'

@description('Role of the VM-03.')
param vm_03_role string = 'cluster-node'

@description('Internal IP address for the VM-01.')
param iip_v4_01_addr string = '172.16.0.100'

@description('Internal IP address for the VM-02.')
param iip_v4_02_addr string = '172.16.1.101'

@description('Internal IP address for the VM-03.')
param iip_v4_03_addr string = '172.16.1.102'

@description('Domain Name for Active Directory.')
param domain_name string = 'neostation.org'

@description('NetBIOS name for the Ad Domain.')
param domain_netbios_name string = 'NEOSTATION'

@description('Private IP address for the Ad Domain Controller.')
param domain_server_ip string = '172.16.0.100'

@description('Name of storage account for the Virtual Machines.')
@minLength(3)
@maxLength(24)
param storage_account_name string = 'mscskrcommonstoragespace'
param mscs_compute_resources_name string = 'mscs_compute_resources'
param mscs_common_resources_name string = 'mscs_common_resources'


// create resource group for compute resources
resource mscs_compute_resources 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: mscs_compute_resources_name
}

// ************************************************************************************************
// Bicep Module for Custom Script Extension for Virtual Machines
// ************************************************************************************************

module custom_script_extension 'cse.bicep' = {
  name: 'mscs_cs_script_extension'
  params: {
    location: mscs_compute_resources.location
    admin_name: admin_name
    admin_password: admin_password
    vm_01_name: vm_01_name
    vm_02_name: vm_02_name
    vm_03_name: vm_03_name
    vm_01_role: vm_01_role
    vm_02_role: vm_02_role
    vm_03_role: vm_03_role
    ii_v4_01_address: iip_v4_01_addr
    iipv4_02_address: iip_v4_02_addr
    iipv4_03_address: iip_v4_03_addr
    domain_name: domain_name
    domain_netbios_name: domain_netbios_name
    domain_server_ip: domain_server_ip
    resource_group_name: mscs_compute_resources_name
    mscs_common_resources_name: mscs_common_resources_name
    storage_account_name: storage_account_name
  }
  dependsOn: [
    mscs_compute_resources
  ]
  scope: mscs_compute_resources
}
