<#
.LICENSE
Copyright (c) Microsoft Corporation. All rights reserved.

.AUTHOR
patrick.shim@live.co.kr (Patrick Shim)

.VERSION
1.0.0.1

.SYNOPSIS
Installs PowerShell 7 and necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. Logs events to the Windows event log and catches any exceptions that occur.

.DESCRIPTION
This script installs PowerShell 7 on a Windows machine if it's not already installed, and then installs the necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. The script logs events to the Windows event log using a custom event source, and catches and logs any exceptions that occur during the execution of the script.

.PARAMETER VmRole
Specifies the role of the virtual machine (`domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node).

.PARAMETER AdminName
Specifies the name of the administrator account for the domain.

.PARAMETER AdminPass
Specifies the password for the administrator account.

.PARAMETER DomainName
Specifies the name of the domain.

.PARAMETER DomainBiosName
Specifies the NetBIOS name of the domain.

.PARAMETER DomainServerIp
Specifies the Private IP Address of the domain server.

.PARAMETER NetworkAdaptorName
Specifies the name of the network adaptor to use for the cluster network. The default value is `Ethernet`.

.EXAMPLE
.\InstallRolesAndFeatures.ps1 -VmRole domaincontroller -AdminName Admin -AdminPass P@ssw0rd -DomainName contoso.com -DomainBiosName CONTOSO -DomainServerIp

.NOTES
- This script requires elevated privileges to run, i.e., as an administrator.
- The `VmRole` parameter must be one of the following: `domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node.
- The `AdminName` and `AdminPass` parameters must specify the name and password of an administrator account for the domain.
- The `DomainName` parameter must specify the name of the domain.
- The `DomainBiosName` parameter must specify the NetBIOS name of the domain.
- The `DomainServerIp` parameter must specify the Private IP Address of the domain server.
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $VmRole,

    [Parameter(Mandatory = $true)]
    [string] $AdminName,
        
    [Parameter(Mandatory = $true)]
    [string] $AdminPass,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainBiosName,
    
    [Parameter(Mandatory = $true)]
    [string] $DomainServerIp,

    [Parameter(Mandatory = $false)]
    [string] $NetworkAdaptorName = "Ethernet"
)

Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory = $true)]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [string] $EventLogName,

        [Parameter(Mandatory = $false)]
        [System.Diagnostics.EventLogEntryType] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    $log = New-Object System.Diagnostics.EventLog($EventLogName)
    $log.Source = $Source
    $log.WriteEntry($Message, $EntryType)
}

Write-EventLog -Message "Starting installation of roles and features (timestamp: $((Get-Date).ToUniversalTime().ToString("o"))." -Source "CustomScriptEvent" -EventLogName "Application"
# Check whether the event source exists, and create it if it doesn't exist.
$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $AdminPass -AsPlainText -Force))
$EventSource = "CustomScriptEvent"
$EventLogName = "Application"

if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) { [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $EventLogName) }

$url = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi"
$msi = "$env:USERPROFILE\\Desktop\\\PowerShell-7.3.2-win-x64.msi"

# Delayed Start (1 minutes) to make sure all component provisioning is ready.
Start-Sleep -Seconds 60

Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
Set-TimeZone -Id "Singapore Standard Time"

# Check if the DNS and URI are working correctly (maybe not necessary with delayed execution of the script)
try {
    $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-EventLog -Message "DNS and URI are working correctly. Status code: $($response.StatusCode)" -Source $EventSource -EventLogName $EventLogName -EntryType Information
    } else {
        Write-EventLog -Message "DNS and URI are not working correctly. Status code: $($response.StatusCode)" -Source $EventSource -EventLogName $EventLogName -EntryType Warning
        return
    }
} catch {
    Write-EventLog -Message "Error checking DNS and URI: $_" -Source $EventSource -EventLogName $EventLogName -EntryType Error
}

# Check if PowerShell 7 is installed by searching for 'pwsh' executable in the PATH
$pwshPath = Get-Command -Name "pwsh" -ErrorAction SilentlyContinue

if (-not $pwshPath) {

    Write-EventLog -Message 'Installation of PowerShell 7 started.' -Source $EventSource -EventLogName $EventLogName
    
    if (-not (Test-Path -Path $msi)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -ErrorAction Stop
            Write-EventLog -Message 'PowerShell 7.3.2 downloaded successfully.' -Source $EventSource -EventLogName $EventLogName
            msiexec.exe /package $msi /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
            write-EventLog -Message 'Installation of PowerShell 7 is completed.' -Source $EventSource -EventLogName $EventLogName
            Install-PackageProvider -Name NuGet -Force
            Install-Module -Name Az -AllowClobber -Force
            Write-EventLog -Message 'Installation of Az module is completed.' -Source $EventSource -EventLogName $EventLogName
     
        } catch {
            Write-EventLog -Message "Error downloading PowerShell 7.3.2: $_" -Source $EventSource -EventLogName $EventLogName
            Write-Error "Error downloading PowerShell 7.3.2: $_"
        }
    }
}

try {
    # Configure Windows Firewall to allow PowerShell Remoting, ICMP, SMB, NFS, and WinRM
    New-NetFirewallRule -DisplayName 'PowerShell Remoting' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985, 5986 -Enabled True
    New-NetFirewallRule -DisplayName 'ICMP' -Direction Inbound -Action Allow -Protocol ICMPv4 -Enabled True
    New-NetFirewallRule -DisplayName 'WinRM' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985, 5986 -Enabled True
    Write-EventLog -Message 'Windows Firewall rules for PowerShell Remoting, ICMP, SMB, NFS, and WinRM are now configured.' -Source $EventSource -EventLogName $EventLogName

    # Configure WSMan to allow unencrypted traffic
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

    $AdRoleExist = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue

    if ($VmRole -in ('domain', 'dc', 'ad', 'dns', 'domain-controller', 'ad-dns', 'dc-dns') ){
        if ($AdRoleExist.InstallState -ne 'Installed') {
            Write-EventLog -Message 'Installation of Active Directory Domain Services started.' -Source $EventSource -EventLogName $EventLogName
            Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeAllSubFeature -IncludeManagementTools
            # Ensure the ADDSDeployment module is installed and available
            Import-Module ADDSDeployment

            Write-EventLog -Message 'Installation of Active Directory Domain Services is now completed.' -Source $EventSource -EventLogName $EventLogName -EntryType information
            Install-ADDSForest -DomainName $DomainName `
                -DomainNetbiosName $DomainBiosName `
                -DomainMode 'WinThreshold' `
                -ForestMode 'WinThreshold' `
                -InstallDns `
                -SafeModeAdministratorPassword $Credential.Password `
                -Force

            # Configure Windws Firewall to allow DNS and all Domain Controller related ports
            New-NetFirewallRule -DisplayName 'DNS' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 53 -Enabled True
            New-NetFirewallRule -DisplayName 'DNS' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 53 -Enabled True
            New-NetFirewallRule -DisplayName 'Kerberos' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 88 -Enabled True
            New-NetFirewallRule -DisplayName 'Kerberos' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 88 -Enabled True
            Write-EventLog -Message 'Configuration of Active Directory Domain Services is now completed.' -Source $EventSource -EventLogName $EventLogName -EntryType information
        }
    }
    else {
        # Give it some time and wait for the domain controller to be ready (5 minutes)
        Start-Sleep -Seconds 600 

        # Check if the domain server IP address is valid
        if (-not (Test-Connection -ComputerName $DomainServerIp -Count 1 -Quiet)) {
            Write-EventLog -Message "Invalid domain server IP address specified: $DomainServerIp" -Source $EventSource -EventLogName $EventLogName -EntryType Error
            return
        }

        Write-EventLog -Message 'Windows Feature Installation and domain join started.' -Source $EventSource -EventLogName $EventLogName -EntryType Information
        Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools -IncludeAllSubFeature
        
        # Configure Windows Firewall to allow SMB, NFS, and SQL Server
        New-NetFirewallRule -DisplayName 'SMB' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 -Enabled True
        New-NetFirewallRule -DisplayName 'NFS' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 2049 -Enabled True
        New-NetFirewallRule -DisplayName 'SQL Server' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -Enabled True
        Write-EventLog -Message 'Windows Feature Installation has completed' -Source $EventSource -EventLogName $EventLogName -EntryType Information

        # Configure NIC to have domain controller / DNS as DNS server.
        $NetworkAdapter = Get-NetAdapter -Name $NetworkAdaptorName
        Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapter.ifIndex -ServerAddresses $DomainServerIp

        # Join the computer to the domain and restart the computer
        Add-Computer -DomainName $DomainName -Credential $Credential -Restart
        Write-EventLog -Message 'Windows Feature Installation has completed' -Source $EventSource -EventLogName $EventLogName -EntryType Information
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message -Source $EventSource -EventLogName $EventLogName -EntryType Error
    Write-Error $_.Exception.Message
}
Write-EventLog -Message "Installation of roles and features completed (timestamp: $((Get-Date).ToUniversalTime().ToString("o"))." -Source "CustomScriptEvent" -EventLogName "Application"
