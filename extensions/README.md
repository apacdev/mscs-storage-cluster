# Install-VmFeatures.ps1
The script is written in PowerShell 5 to configure a Windows Server 2022 environment from Azure deployment (Custom Script Extension). It installs PowerShell 7 and Az Modules on a Windows machine. The script also installs the necessary roles and features for either a Active Directory Domain Controller or a node in a Windows Failover Cluster. The script logs events to the Windows Event Log using a custom event source, and catches and logs any exceptions that occur during the execution of the script.

## License
Copyright (c) Microsoft Corporation. All rights reserved.

## Author
patrick.shim@live.co.kr (Patrick Shim)

## Version
1.0.0.2

## Synopsis
Installs PowerShell 7 and necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. Logs events to the Windows event log and catches any exceptions that occur.

# Parameters
- ResrourceGroupName: Specifies a Azure Resource Group for it to register cluster node VMs
- VmRole: Specifies the role of the virtual machine (domain, domaincontroller, or dc for a domain controller; anything else for a node).
- AdminName: Specifies the name of the administrator account for the domain.
- AdminPass: Specifies the password for the administrator account.
- DomainName: Specifies the name of the domain.
- DomainNetBiosName: Specifies the NetBIOS name of the domain.
- DomainServerIp: Specifies the Private IP Address of the domain server.

# Examples
```
powershell.exe .\InstallRolesAndFeatures.ps1 -VmRole domaincontroller -AdminName Admin -AdminPass P@ssw0rd -DomainName contoso.com -DomainNetBiosName CONTOSO -DomainServerIp 192.168.0.1
```

# Structure of the Custom Script Extension
It first logs an event stating that the installation of roles and features has started. Then, it sets a default VM environment, installs PowerShell with Azure modules, and based on the $VmRole value, it either configures an Active Directory Domain Controller or a Failover Cluster and File Server. Finally, it logs an event that the installation is completed, or if an exception occurs, it logs the error message.

## Here's a high-level overview of the script:
- Log an event that the installation of roles and features has started.
- Set a default VM environment with given $tempPath and $timeZone.
- Install PowerShell with Azure modules using the provided $url and $msiPath.
- Check if $VmRole matches the Domain Controller role pattern:

  A. If it does, configure Active Directory Domain Controller:
    - Set required firewall rules.
    - Install required Windows Features.
    - Configure Active Directory Domain Services.

  B. If it does not, configure Failover Cluster and File Server:
    - Set required firewall rules.
    - Install required Windows Features.
    - Wait for Domain Controller availability.
    - Join the domain if not already joined, and reboot.

- Log an event that the installation of roles and features is completed.
- Catch any exceptions and log the error message.

## List of Functions in the Script
- Set-DefaultVmEnvironment, 
- Install-PowerShellWithAzModules, 
- Set-RequiredFirewallRules, etc.

## Test-DcAvailability function:
This function checks the availability of a domain controller by testing the network connection and Domain Name System (DNS) port. It takes a mandatory parameter $ServerIpAddress and performs the following tests:
- Ping the domain controller using the Test-NetConnection cmdlet.
- Check if the TCP connection to the DNS port (53) is reachable.
- Check if the domain controller is available using the Get-ADDomainController cmdlet.
- Depending on the test results, it writes relevant messages to the event log and returns either $true or $false.

## Wait-DcAvailability function:
This function repeatedly calls the Test-DcAvailability function until the domain controller becomes available or the specified timeout is reached. It takes the following parameters:

- $ServerIpAddress (mandatory): the IP address of the domain controller.
- $TimeoutInSeconds (optional, default 60): the maximum time to wait for the domain controller.
- $IntervalInSeconds (optional, default 1): the interval between availability checks.

The function returns $true if the domain controller becomes available within the specified timeout, and $false otherwise.

## Join-DomainIfNotJoined function:
This function joins the computer to a specified domain if it is not already a member of the domain. It takes the following parameters:
- $DomainName (mandatory): the name of the domain to join.
- $DomainServerIpAddress (mandatory): the IP address of the domain controller.
- $Credential (mandatory): the credential to use when joining the domain.
- $Reboot (optional, default $true): whether to reboot the computer after joining the domain.

The function sets the DNS server address, checks if the computer is already a member of the domain, and joins the domain if necessary. It also writes relevant messages to the event log. At the end of the script, the Wait-DcAvailability function is called with a 20-minute timeout and 5-second intervals. If the domain controller is available, the Join-DomainIfNotJoined function is called to join the computer to the domain.

# Notes
- This script requires elevated privileges to run, i.e., as an administrator.
- The VmRole parameter must be one of the following: domain, domaincontroller, or dc for a domain controller; anything else for a node.

# Contribution Guidelines
If you'd like to contribute to this project, please submit a pull request or create an issue on the Github repository.

# Contact Information
If you have any questions or concerns, please contact the author at patrick.shim@live.co.kr.
