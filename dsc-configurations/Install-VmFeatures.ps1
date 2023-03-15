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

    Write-EventLog -LogName $EventLogName -Source $Source -EntryType $EntryType -EventId 1 -Message $Message
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
    if ($VmRole -eq 'domain' -or $VmRole -eq 'domaincontroller' -or $VmRole -eq 'dc') {
        Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeAllSubFeature -IncludeManagementTools
        # Ensure the ADDSDeployment module is installed and available
        if (-not (Get-Module -ListAvailable -Name ADDSDeployment)) {
            Write-Error "The ADDSDeployment module is not available. Please ensure that the Active Directory Domain Services role and its management tools are installed."
            return
            Import-Module ADDSDeployment
            Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainBiosName `
                -DomainMode 'WinThreshold' `
                -ForestMode 'WinThreshold' `
                -InstallDns `
                -DomainAdministratorCredential $Credential `
                -SafeModeAdministratorPassword $Credential.Password `
                -Restart -Force
            Write-EventLog -Message 'Installation of Active Directory Domain Services is now completed.' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType information
        }
    }
    else {
        Install-WindowsFeature -Name Failover-Clustering, FS-FileServer -IncludeManagementTools -IncludeAllSubFeature
        Start-Sleep -Seconds 120
        Add-Computer -DomainName $DomainName -Credential $Credential -Restart
        Write-EventLog -Message 'Windows Feature Installation has completed' -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Information
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message -Source 'CustomScriptEvent' -EventLogName 'Application' -EntryType Error
    Write-Error $_.Exception.Message
}
