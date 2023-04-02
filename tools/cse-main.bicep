targetScope = 'subscription'

// ************************************************************************************************
// Role: Azure Bicep Template for Microsoft Cluster Services (MSCS) on Windows Server 2022
// Author:  Patrick Shim (patrick.shim@live.co.kr)
// Copyright (C) 2023 by Microsoft Corporation
// ************************************************************************************************

@description('Admin Username for the Virtual Machine and Ad Domain.')
param admin_name string = 'ContosoAdmin'

@description('Admin Password for the Virtual Machine and Ad Domain.')
@maxLength(18)
@secure()
param admin_password string

@description('Name of the resource group to create.')
@allowed([
  'mscs_compute_resources'
  'mscs_network_resources'
  'mscs_storage_resources'
  'mscs_common_resources'
])

param mscs_compute_resources_name string = 'mscs_compute_resources'
param mscs_common_resources_name string  = 'mscs_common_resources'

@description('Name of the VM-01.')
param vm_01_name string = 'mscswvm-01'

@description('Name of the VM-02.')
param vm_02_name string = 'mscswvm-node-02'

@description('Name of the VM-03.')
param vm_03_name string = 'mscswvm-node-03'

@description('Role of the VM-01.')
param vm_01_role string = 'ad-domain'

@description('Role of the VM-02.')
param vm_02_role string = 'cluster-node'

@description('Role of the VM-03.')
param vm_03_role string = 'cluster-node'

@description('Domain Name for Active Directory.')
param domain_name string = 'contoso.org'

@description('NetBIOS name for the Ad Domain.')
param domain_netbios_name string = 'CONTOSO'

@description('Private IP address for the Ad Domain Controller.')
param domain_server_ip string = '172.16.0.100'

@description('Name for the Failover Cluster.')
param cluster_name string = 'mscs-cluster'

@description('IPv4 Address for Cluster Instance.')
param cluster_ip string = '172.16.1.50'

@description('Cluster Role IPv4 Address (should match with Frontend IP of Internal Load Balancer).')
param cluster_role_ip string = '172.16.1.100'

@description('Name for the Cluster Network.')
param cluster_network_name string = 'Cluster Network 1'

@description('Port for the Cluster Probe.')
param cluster_probe_port string = '61800'

@description('Name of storage account for the Virtual Machines.')
@minLength(3)
@maxLength(24)
param storage_account_name string = 'mscskrcommonstoragespace'

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

    domain_name: domain_name
    domain_netbios_name: domain_netbios_name
    domain_server_ip: domain_server_ip

    cluster_name: cluster_name
    cluster_ip: cluster_ip
    cluster_role_ip: cluster_role_ip
    cluster_network_name: cluster_network_name
    cluster_probe_port: cluster_probe_port

    storage_account_name: storage_account_name
    mscs_common_resources_name: mscs_common_resources_name
  }
  dependsOn: [
    mscs_compute_resources
  ]
  scope: mscs_compute_resources
}
