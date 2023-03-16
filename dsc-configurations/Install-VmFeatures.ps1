<#
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

.EXAMPLE
.\InstallRolesAndFeatures.ps1 -VmRole domain -AdminName Admin -AdminPass P@ssw0rd -DomainName contoso.com -DomainBiosName CONTOSO

.NOTES
- This script requires elevated privileges to run, i.e., as an administrator.
- The `VmRole` parameter must be one of the following: `domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node.
- The `AdminName` and `AdminPass` parameters must specify the name and password of an administrator account for the domain.
- The `DomainName` parameter must specify the name of the domain.
- The `DomainBiosName` parameter must specify the NetBIOS name of the domain.
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
    [string] $DomainServerIp
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
}

$eventSource = "CustomScriptEvent"

if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($eventSource, 'Application')
}

$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $AdminPass -AsPlainText -Force))
$url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi'
$msi = 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi'

if ($PSVersionTable.PSVersion.Major -lt 7) {    
    
    Write-EventLog -Message 'PowerShell 7 is not installed, starting with download and installation' -Source 'CustomScriptEvent' -EventLogName 'Application'
    
    if (-not (Test-Path -Path $msi)) {
        Invoke-WebRequest -Uri $url -OutFile $msi
    }
    
    msiexec.exe /package 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi' /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
    Write-EventLog -Message 'Installation of PowerShell 7 is now completed.' -Source 'CustomScriptEvent' -EventLogName 'Application'
    
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
    
    Write-EventLog -Message 'The execution of the Custom Script (WSMan Authentication) has been started.' -Source 'CustomScriptEvent' -EventLogName 'Application'
}

try {
    if ($VmRole -match '^(ad|domain|domaincontroller|dc)$' -as [bool]) {
        Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeAllSubFeature -IncludeManagementTools
        Write-EventLog -Message 'Installation of Active Directory Domain Services is now completed.' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType information
        Start-Sleep -Seconds 30
        # Ensure the ADDSDeployment module is installed and available
        Import-Module ADDSDeployment
        Install-ADDSForest -DomainName $DomainName `
            -DomainNetbiosName $DomainBiosName `
            -DomainMode 'WinThreshold' `
            -ForestMode 'WinThreshold' `
            -InstallDns `
            -SafeModeAdministratorPassword $Credential.Password `
            -Force
        Write-EventLog -Message 'Configuration of Active Directory Domain Services is now completed.' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType information
    }
    else {
        Write-EventLog -Message 'Windows Feature Installation (node) started.' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Information
        Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools -IncludeAllSubFeature
        Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "$DomainServerIp $DomainName"
        # Check if the entry already exists in the hosts file
        if ($null -eq (Select-String -Path $HostsFilePath -Pattern "^$IPAddress\s+$DomainName")) {
            Add-Content -Path $HostsFilePath -Value "$IPAddress $DomainName"
            Write-EventLog -Message 'Private IP of Domain Controller added to the Hosts file.' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Information
        }
        Add-Computer -DomainName $DomainName -Credential $Credential
        Write-EventLog -Message 'Windows Feature Installation has completed' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Information
        Start-Sleep -Seconds 30
        Restart-Computer -Force
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Error
    Write-Error $_.Exception.Message
}
