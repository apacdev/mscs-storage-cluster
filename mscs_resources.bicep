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

param mscs_network_resources_name string = 'mscs_network_resources'
param mscs_storage_resources_name string = 'mscs_storage_resources'
param mscs_compute_resources_name string = 'mscs_compute_resources'
param mscs_common_resources_name string  = 'mscs_common_resources'

@description('Location for resources.')
@allowed([
  'westus2'
  'southeastasia'
  'japaneast'
  'koreacentral'
])
param location string = 'southeastasia'

@description('Name of LogAnalytics Workspace.')
param log_space_name string = 'mscs-log-workspace'

@description('Name of Azure Automate instance.')
param automate_name string = 'mscs-vms-automate'

@description('Name of Shared Disk for the nodes.')
param disk_name string = 'mscs-asd-clusterdisk'

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

@description('Name of Internal Loadbalancer.')
param ilb_name string = 'mscs-ilb'

@description('IP for Cluster Role and Load Balancer Frontend.')
param ilb_ipv4_addr string = '172.16.1.100'

@description('Internal IP address for the VM-01.')
param iip_v4_01_addr string = '172.16.0.100'

@description('Internal IP address for the VM-02.')
param iip_v4_02_addr string = '172.16.1.101'

@description('Internal IP address for the VM-03.')
param iip_v4_03_addr string = '172.16.1.102'

@description('Port number for Probe.')
param probe_port string = '61800'

@description('IPv4 address-space for the Virtual Network.')
param vnet_ipv4_addr string = '172.16.0.0/16'

@description('IPv6 address-space for the Virtual Network.')
param vnet_ipv6_addr string = 'fd00:db8:deca::/48'

@description('IPv4 address-space for the subnet-01.')
param subnet_v4_01_addr string = '172.16.0.0/24'

@description('IPv4 address-space for the subnet-02.')
param subnet_v4_02_addr string = '172.16.1.0/24'

@description('IPv6 address-space for the subnet-01.')
param subnet_v6_01_addr string = 'fd00:db8:deca:deec::/64'

@description('IPv6 address-space for the subnet-02.')
param subnet_v6_02_addr string = 'fd00:db8:deca:deed::/64'

@description('Domain Name for Active Directory.')
param domain_name string = 'contoso.org'

@description('NetBIOS name for the Ad Domain.')
param domain_netbios_name string = 'CONTOSO'

@description('Private IP address for the Ad Domain Controller.')
param domain_server_ip string = '172.16.0.100'

@description('Name of Network Security Group.')
param nsg_name string = 'mscs-nsg'

@description('Name of Virtual Network.')
param vnet_name string  = 'mscs-vnet'

@description('Name of First Subnet (/24).')
param subnet_01_name string  = 'subnet_01'

@description('Name of Second Subnet (/24).')
param subnet_02_name string  = 'subnet_02'

@description('Name of Network Interface for VM-01.')
param nic_01_name string  = 'nic_vm_01'

@description('Name of Network Interface for VM-02.')
param nic_02_name string  = 'nic_vm_02'

@description('Name of Network Interface for VM-03.')
param nic_03_name string  = 'nic_vm_03'

@description('Public IP address name for NIC-01.')
param eip_v4_01_name string  = 'eip_v4_01'

@description('Public IP address name for NIC-02.')
param eip_v4_02_name string  = 'eip_v4_02'

@description('Public IP address name for NIC-03.')
param eip_v4_03_name string  = 'eip_v4_03'

@description('Public IPv6 address name for NIC-01.')
param eip_v6_01_name string  = 'eip_v6_01'

@description('Public IPv6 address name for NIC-02.')
param eip_v6_02_name string  = 'eip_v6_02'

@description('Public IPv6 address name for NIC-03.')
param eip_v6_03_name string  = 'eip_v6_03'

@description('Sku for the LogAnalytics Workspace.')
param log_space_sku string  = 'PerGB2018'

@description('Name for the Failover Cluster.')
param cluster_name string = 'mscs-cluster'

@description('IPv4 Address for Cluster Instance.')
param cluster_ip string = '172.16.1.50'

@description('Cluster Role IPv4 Address (should match with Frontend IP of Internal Load Balancer).')
param cluster_role_ip string = ilb_ipv4_addr

@description('Name for the Cluster Network.')
param cluster_network_name string = 'Cluster Network 1'

@description('Port for the Cluster Probe.')
param cluster_probe_port string = probe_port

@description('Allowed size of the Virtual Machines.')
@allowed([
  'Standard_F4s_v2'
  'standard_E4s_v4'
  'Standard_E4s_v4'
])
param vm_size string = 'Standard_F4s_v2'

@description('Name of storage account for the Virtual Machines.')
@minLength(3)
@maxLength(24)
param storage_account_name string = 'mscskrcommonstoragespace'

// create resource group for network resources
resource mscs_network_resources 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: mscs_network_resources_name
  location: location
}

// create resource group for storage resources
resource mscs_storage_resources 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: mscs_storage_resources_name
  location: location
}

// create resource group for compute resources
resource mscs_common_resources 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: mscs_common_resources_name
  location: location
}

// create resource group for compute resources
resource mscs_compute_resources 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: mscs_compute_resources_name
  location: location
}

// ************************************************************************************************
// Bicep Module for Network Resources
// ************************************************************************************************

module vnet_resources 'mscs_network_module.bicep' = {
  name: 'mscs_network_module'
  params: {
    location: mscs_network_resources.location
    vnet_name: vnet_name
    nsg_name: nsg_name
    
    // virtual machine names
    vm_01_name: vm_01_name
    vm_02_name: vm_02_name
    vm_03_name: vm_03_name
    
    // network interface names
    nic_01_name: nic_01_name
    nic_02_name: nic_02_name
    nic_03_name: nic_03_name
    
    // ipv4 and ipv6 address spaces for vnet
    vnet_ipv4_addr: vnet_ipv4_addr
    vnet_ipv6_addr: vnet_ipv6_addr
    
    // subnet names
    subnet_01_name: subnet_01_name
    subnet_02_name: subnet_02_name

    // ipv4_addr subnet address space
    subnet_01_ipv4_addr: subnet_v4_01_addr
    subnet_02_ipv4_addr: subnet_v4_02_addr
 
    // ipv6_addr subnets address spaces
    subnet_01_ipv6_addr: subnet_v6_01_addr
    subnet_02_ipv6_addr: subnet_v6_02_addr
 
    // internal network address
    iip_v4_01_addr: iip_v4_01_addr
    iip_v4_02_addr: iip_v4_02_addr
    iip_v4_03_addr: iip_v4_03_addr
 
    // public ipv4 addresses
    eip_v6_01_name: eip_v6_01_name
    eip_v6_02_name: eip_v6_02_name
    eip_v6_03_name: eip_v6_03_name
 
    // public ipv6 addresses
    eip_v4_01_name: eip_v4_01_name
    eip_v4_02_name: eip_v4_02_name
    eip_v4_03_name: eip_v4_03_name

    // load balancer
    ilb_name: ilb_name
    lib_ipv4_addr: ilb_ipv4_addr
    ilb_probe_port: probe_port
  }
  scope: mscs_network_resources
}

// ************************************************************************************************
// Bicep Module for Storage Resources
// ************************************************************************************************

module stroage_resources 'mscs_storage_module.bicep' = {
  name: 'mscs_storage_module'
  params: {
    location: mscs_storage_resources.location
    disk_name: disk_name
  }
  scope: mscs_storage_resources
}

// ************************************************************************************************
// Bicep Module for Compute Resources
// ************************************************************************************************

module compute_resources 'mscs_compute_module.bicep' = {
  name: 'mscs_compute_module'
  params: {
    location: mscs_compute_resources.location
    vm_01_name: vm_01_name
    vm_02_name: vm_02_name
    vm_03_name: vm_03_name
    mscs_network_resources_name: mscs_network_resources_name
    mscs_storage_resources_name: mscs_storage_resources_name
    mscs_common_resources_name: mscs_common_resources_name
    disk_name: disk_name
    storage_account_name: storage_account_name
    nic_vm_01_name: nic_01_name
    nic_vm_02_name: nic_02_name
    nic_vm_03_name: nic_03_name
    vm_size: vm_size
    admin_name: admin_name
    admin_password: admin_password
  }
  dependsOn: [
    common_resources
  ]
  scope: mscs_compute_resources
}

// ************************************************************************************************
// Bicep Module for Custom Script Extension for Virtual Machines
// ************************************************************************************************

module custom_script_extension 'mscs_extension_module.bicep' = {
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
    compute_resources
  ]
  scope: mscs_compute_resources
}

// ************************************************************************************************
// Bicep Module for Common Resources
// ************************************************************************************************

module common_resources 'mscs_common_module.bicep' = {
  name: 'mscs_common_module'
  params: {
    location: mscs_common_resources.location
    storage_account_name: storage_account_name
    automate_name: automate_name
    log_space_name: log_space_name
    log_space_sku: log_space_sku
  }
  dependsOn: [
    vnet_resources
    stroage_resources
  ]
  scope: mscs_common_resources
}
