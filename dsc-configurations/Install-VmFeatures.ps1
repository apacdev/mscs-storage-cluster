param(
    [Parameter(Mandatory = $true)]
    [string] $VmRole,

    [Parameter(Mandatory = $true)]
    [string] $UserName,
        
    [Parameter(Mandatory = $true)]
    [secureString] $Password,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainBiosName
)
    
$Credential = New-Object System.Management.Automation.PSCredential($UserName, $Password)
    
try {

    $ps7 = pwsh -Command '$PSVersionTable.PSVersion.Major'

    if (($ps7 -ne 7) -or ($ps7 -le 5) -or ($ps7 -eq $null)) {
        Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi' -OutFile 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi'
        msiexec.exe /package 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi' /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
    }
    # Enable basic authentication and allow unencrypted traffic in WSMan
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

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
