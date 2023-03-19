Install-VmFeatures.ps1

This script installs PowerShell 7 on a Windows machine if it's not already installed, and then installs the necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. The script logs events to the Windows event log using a custom event source, and catches and logs any exceptions that occur during the execution of the script.



.\InstallRolesAndFeatures.ps1 -VmRole domaincontroller -AdminName Admin -AdminPass P@ssw0rd -DomainName contoso.com -DomainBiosName CONTOSO -DomainServerIp 192.168.0.1
