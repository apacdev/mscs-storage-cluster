param location string = resourceGroup().location
param disk_name string

// create a shared disk of premium ssd type.  the max size is 2TB, max share is 2 bwetween 2 VMs.
resource disk_resource 'Microsoft.Compute/disks@2022-07-02' = {
  name: disk_name
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  zones: ['2']

  properties: {
    maxShares: 2
    diskSizeGB: 2048
    diskIOPSReadWrite: 1024
    diskMBpsReadWrite: 256
    creationData: {
      createOption: 'Empty'
    }
  }
}
