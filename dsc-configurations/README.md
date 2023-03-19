# Install-VmFeatures.ps1

This script installs PowerShell 7 and Az Modules on a Windows machine. It also installs the necessary roles and features for either a Active Directory Domain Controller or a node in a Windows Failover Cluster.  It is meant to be a CustomScript Extension implementation which is run-once when a Virtual Machine is deployed on Microsoft Azure.  The script logs events to the Windows Event Log using a custom event source, and catches and logs any exceptions that occur during the execution of the script.

## License
Copyright (c) Microsoft Corporation. All rights reserved.

## Author
patrick.shim@live.co.kr (Patrick Shim)

## Version
1.0.0.2

## Synopsis
Installs PowerShell 7 and necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. Logs events to the Windows event log and catches any exceptions that occur.

# Parameters
- VmRole: Specifies the role of the virtual machine (domain, domaincontroller, or dc for a domain controller; anything else for a node).
- AdminName: Specifies the name of the administrator account for the domain.
- AdminPass: Specifies the password for the administrator account.
- DomainName: Specifies the name of the domain.
- DomainBiosName: Specifies the NetBIOS name of the domain.
- DomainServerIp: Specifies the Private IP Address of the domain server.

# Examples
```powershell .\InstallRolesAndFeatures.ps1 -VmRole domaincontroller -AdminName Admin -AdminPass P@ssw0rd -DomainName contoso.com -DomainBiosName CONTOSO -DomainServerIp 192.168.0.1```

# Notes
- This script requires elevated privileges to run, i.e., as an administrator.
- The VmRole parameter must be one of the following: domain, domaincontroller, or dc for a domain controller; anything else for a node.
- The AdminName and AdminPass parameters must specify the name and password of an administrator account for the domain.
- The DomainName parameter must specify the name of the domain.
- The DomainBiosName parameter must specify the NetBIOS name of the domain.
- The DomainServerIp parameter must specify the Private IP Address of the domain server.

# Contribution Guidelines
If you'd like to contribute to this project, please submit a pull request or create an issue on the Github repository.

# Contact Information
If you have any questions or concerns, please contact the author at patrick.shim@live.co.kr.
