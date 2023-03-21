# Highly Available Storage Server on Microsoft Clustering Service
An Example template to Create Highly Available Failover Cluster using Microsoft Clustering Service with Azure Shared Disk.

# Multi-Server Cluster Deployment in Bicep
This Bicep template deploys a multi-server cluster on Microsoft Azure. The deployment creates three virtual machines (VMs) with a specific VM size, network interfaces, and shared storage configuration. The Custom Script Extension is used to automate configurations of each VMs post-deployment.

# Features
* Modular structure which has reource definitions for each resource type (i.e. Network, Storage, Compute, etc.).
* Deploys three Windows Server 2022 VMs on Microsoft Azure: 1 x Ad Domain, 2 x Cluster Nodes
* Deploys one Azure Shared Disk attached to each VMs: Cluster Shared Volume
* Leverages two Azure Availability Zones: Az-01 for VM-01, Az-02 for VM-02 and VM-03

# Usage Example
```
az login
az deployment group create --resource-group <BaseResourceGroupName> --template-file mscs_resources.bicep --parameters param1=value1 param2=value2 ... 
```

# Parameters
