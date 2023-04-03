@description('Location of network related resources. Default is the Location used for Resource Group.')
param location string = resourceGroup().location

@description('Name of the virtual network (/16).')
param vnet_name string

@description('Name of the network security group.')
param nsg_name string

@description('Name of the Virtual Machine 01.')
param vm_01_name string

@description('Name of the Virtual Machine 02.')
param vm_02_name string

@description('Name of the Virtual Machine 03.')
param vm_03_name string

@description('Subnet 01 name.')
param subnet_01_name string

@description('Subnet 02 name.')
param subnet_02_name string

@description('IPv4 address space for the virtual network (/16).')
param vnet_ipv4_addr string

@description('IPv6 address space for the virtual network (/16).')
param vnet_ipv6_addr string

@description('IPv4 address space for the subnet 01 (/24).')
param subnet_01_ipv4_addr string

@description('IPv6 address space for the subnet 01 (/24).')
param subnet_02_ipv4_addr string

@description('IPv4 address space for the subnet 02 (/24).')
param subnet_01_ipv6_addr string

@description('IPv6 address space for the subnet 02 (/24).')
param subnet_02_ipv6_addr string

@description('Private IPv4 address for the Virtual Machine 01.')
param iip_v4_01_addr string

@description('Private IPv4 address for the Virtual Machine 02.')
param iip_v4_02_addr string

@description('Private IPv4 address for the Virtual Machine 03.')
param iip_v4_03_addr string

@description('Public IPv4 address for the Virtual Machine 01.')
param eip_v4_01_name string

@description('Public IPv4 address for the Virtual Machine 02.')
param eip_v4_02_name string

@description('Public IPv4 address for the Virtual Machine 03.')
param eip_v4_03_name string

@description('Private IPv6 address for the Virtual Machine 01.')
param eip_v6_01_name string

@description('Private IPv6 address for the Virtual Machine 02.')
param eip_v6_02_name string

@description('Private IPv6 address for the Virtual Machine 03.')
param eip_v6_03_name string

@description('Name of Network Interface 01.')
param nic_01_name string

@description('Name of Network Interface 02.')
param nic_02_name string

@description('Name of Network Interface 03.')
param nic_03_name string

@description('Name of Internal Load Balancer.')
param ilb_name string

@description('Port Number for Probe.')
param ilb_probe_port string

@description('IPv4 address for the Internal Load Balancer.')
param lib_ipv4_addr string

// create resource for Virtual Network (x.x.x.x/16)
resource vnet_resource 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnet_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_ipv4_addr
        vnet_ipv6_addr
      ]
    }
    flowTimeoutInMinutes: 4
    subnets: [
      {
        name: subnet_01_name
        properties: {
          networkSecurityGroup: {
            id: nsg_resource.id
          }
          addressPrefixes: [
            subnet_01_ipv4_addr
            subnet_01_ipv6_addr
          ]
          delegations: []
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: subnet_02_name
        properties: {
          networkSecurityGroup: {
            id: nsg_resource.id
          }
          addressPrefixes: [
            subnet_02_ipv4_addr
            subnet_02_ipv6_addr
          ]
          delegations: []
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    bgpCommunities: {
      virtualNetworkCommunity: '12076:36755'
    }
  }
}
output vnet_resource_id string = vnet_resource.id
output subnet array = [{
  subnet_01: {
    name: subnet_01_name
    id: subnet_01_resource.id
  }
  subnet_02: {
    name: subnet_02_name
    id: subnet_02_resource.id
  }
}]

// create resource for Subnet 01 (x.x.1.x/24)
resource subnet_01_resource 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  parent: vnet_resource
  name: subnet_01_name
  properties: {
    addressPrefixes: [
      subnet_01_ipv4_addr
      subnet_01_ipv6_addr
    ]
    networkSecurityGroup: {
      id: nsg_resource.id
    }
  }
}

// create resource for Subnet 02 (x.x.2.x/24)
resource subnet_02_resource 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  parent: vnet_resource
  name: subnet_02_name
  properties: {
    addressPrefixes: [
      subnet_02_ipv4_addr
      subnet_02_ipv6_addr
    ]
    networkSecurityGroup: {
      id: nsg_resource.id
    }
  }
}

// create resource for Network Security Group for Vnet (and NICs)
resource nsg_resource 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsg_name
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow_tcp_53'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_udp_53'
        properties: {
          priority: 101
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_tcp_5986'
        properties: {
          priority: 102
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5986'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_tcp_135'
        properties: {
          priority: 103
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '135'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_tcp_389'
        properties: {
          priority: 104
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_tcp_636'
        properties: {
          priority: 105
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'tcp'
          sourcePortRange: '*'
          destinationPortRange: '636'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_tcp_088'
        properties: {
          priority: 106
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '88'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_udp_088'
        properties: {
          priority: 107
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'udp'
          sourcePortRange: '*'
          destinationPortRange: '88'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_udp_464'
        properties: {
          priority: 108
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'udp'
          sourcePortRange: '*'
          destinationPortRange: '464'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_udp_389'
        properties: {
          priority: 109
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'udp'
          sourcePortRange: '*'
          destinationPortRange: '389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow_udp_636'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'udp'
          sourcePortRange: '*'
          destinationPortRange: '636'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Public IPv4 Address for Network Interface and Virtual Machine 01
resource eip_v4_01_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v4_01_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '1' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: vm_01_name
    }
  }
}

// Public IPv4 Address for Network Interface and Virtual Machine 02
resource eip_v4_02_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v4_02_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '2' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: vm_02_name
    }
  }
}

// Public IPv4 Address for Network Interface and Virtual Machine 03
resource eip_v4_03_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v4_03_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '2' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: vm_03_name
    }
  }
}

// Public IPv6 Address for Network Interface and Virtual Machine 01
resource eip_v6_01_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v6_01_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '1' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
    dnsSettings: {
      domainNameLabel: vm_01_name
    }
  }
}

// Public IPv6 Address for Network Interface and Virtual Machine 02
resource eip_v6_02_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v6_02_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '2' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
    dnsSettings: {
      domainNameLabel: vm_02_name
    }
  }
}

// Public IPv6 Address for Network Interface and Virtual Machine 03
resource eip_v6_03_resource 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: eip_v6_03_name
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [ '2' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
    dnsSettings: {
      domainNameLabel: vm_03_name
    }
  }
}

// create resource for Network Interface for Virtual Machine 01
resource nic_01_resource 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nic_01_name
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg_resource.id
    }
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipv4config'
        properties: {
          primary: true
          subnet: {
            id: subnet_01_resource.id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: iip_v4_01_addr
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: eip_v4_01_resource.id
          }
        }
      }
      {
        name: 'ipv6config'
        properties: {
          publicIPAddress: {
            id: eip_v6_01_resource.id
          }
          subnet: {
            id: subnet_01_resource.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv6'
        }
      }
    ]
  }
}

// create resource for Network Interface 02
resource nic_02_resource 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nic_02_name
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg_resource.id
    }
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipv4config'
        properties: {
          primary: true
          subnet: {
            id: subnet_02_resource.id
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', ilb_name, 'pool')
            }
          ]
          privateIPAllocationMethod: 'Static'
          privateIPAddress: iip_v4_02_addr
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: eip_v4_02_resource.id
          }
        }
      }
      {
        name: 'ipv6config'
        properties: {
          subnet: {
            id: subnet_02_resource.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv6'
          publicIPAddress: {
            id: eip_v6_02_resource.id
          }
        }
      }
    ]
  }
  dependsOn:[
    ilb_resource
  ]
}

// create resource for Network Interface 03
resource nic_03_resource 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: nic_03_name
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg_resource.id
    }
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipv4config'
        properties: {
          primary: true
          subnet: {
            id: subnet_02_resource.id
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', ilb_name, 'pool')
            }
          ]
          privateIPAllocationMethod: 'Static'
          privateIPAddress: iip_v4_03_addr
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: eip_v4_03_resource.id
          }
        }
      }
      {
        name: 'ipv6config'
        properties: {
          subnet: {
            id: subnet_02_resource.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv6'
          publicIPAddress: {
            id: eip_v6_03_resource.id
          }
        }
      }
    ]
  }
  dependsOn:[
    ilb_resource
  ]
}

// create resource for Load Balancer
resource ilb_resource 'Microsoft.Network/loadBalancers@2022-09-01' = {
  name: ilb_name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'front'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: lib_ipv4_addr
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnet_02_resource.id
          }
        }
        zones: [ 
          '1' 
          '2' 
          '3' 
        ]
      }
    ]
    backendAddressPools: [ { 
        name: 'pool'
      }
    ]
    loadBalancingRules: [ {
        name: 'rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', ilb_name, 'front')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', ilb_name, 'pool')
          }
          protocol: 'All'
          frontendPort: 0
          backendPort: 0
          enableFloatingIP: false
          idleTimeoutInMinutes: 15
          loadDistribution: 'Default'
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', ilb_name, 'probe')
          }
        }
      }
    ]
    probes: [ {
        name: 'probe'
        properties: {
          protocol: 'Tcp'
          port: int(ilb_probe_port)
          intervalInSeconds: 15
          numberOfProbes: 5
        }
      }
    ]
  }
}
