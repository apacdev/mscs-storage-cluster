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
    [string] $DomainBiosName
)

$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $AdminPass -AsPlainText -Force))
$url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi'

# write function to log to Windows Event Log
Function Write-EventLog {

    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory = $true)]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [string] $EventLogName
    )

    $eventLog = New-Object System.Diagnostics.EventLog($EventLogName)
    $eventLog.Source = $Source
    $eventLog.WriteEntry($Message, [System.Diagnostics.EventLogEntryType]::Information)
}

if ($PSVersionTable.PSVersion.Major -lt 7) {    
    # Install PowerShell 7 
    Write-EventLog -Message 'PowerShell 7 is not installed, starting with download and installation' -Source 'CustomScriptEvent' -EventLogName 'Application'
    Invoke-WebRequest -Uri $url -OutFile 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi'
    msiexec.exe /package 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi' /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
    Write-EventLog -Message 'Installation of PowerShell 7 is now completed.' -Source 'CustomScriptEvent' -EventLogName 'Application'
    # Enable basic authentication and allow unencrypted traffic in WSMan
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Write-EventLog -Message 'The execution of the Custom Script (WSMan Authentication) has been started.' -Source 'CustomScriptEvent' -EventLogName 'Application'
}

try {

    if ($VmRole -eq 'domain' -or $VmRole -eq 'domaincontroller' -or $VmRole -eq 'dc') {
        # Install Active Directory Domain Services and promote to a domain controller
        Install-WindowsFeature -Name AD-Domain-Services, DNS -Credential $Credential -IncludeAllSubFeature -IncludeManagementTools
        Import-Module ADDSDeployment 
        Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainBiosName `
            -DomainMode 'WinThreshold' `
            -ForestMode 'WinThreshold' `
            -InstallDns `
            -DomainAdministratorCredential $Credential `
            -SafeModeAdministratorPassword $Credential.Password `
            -Force
            $eventLog = New-Object System.Diagnostics.EventLog("Application")
            $eventLog.Source = "CustomScriptEvent"
            $eventLog.WriteEntry('The execution of the Custom Script (Domain Controller) has been completed successfuly.', [System.Diagnostics.EventLogEntryType]::Information)
    }
    else {
        # Install failover clustering and file server features
        Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools -IncludeAllSubFeature
        Add-Computer -DomainName $DomainName -Credential $Credential -Restart
        $eventLog = New-Object System.Diagnostics.EventLog("Application")
        $eventLog.Source = "CustomScriptEvent"
        $eventLog.WriteEntry('The execution of the Custom Script (Cluster Node) has been completed successfuly.', [System.Diagnostics.EventLogEntryType]::Information)
    }
}
catch {
    # If an error occurs, log it to the Windows event log and write to the console
    $eventLog = New-Object System.Diagnostics.EventLog("Application")
    $eventLog.Source = "CustomScriptEvent"
    $eventLog.WriteEntry($_.Exception.Message, [System.Diagnostics.EventLogEntryType]::Error)
    Write-Error $_.Exception.Message
}
