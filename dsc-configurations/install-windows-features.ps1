# Define the event source and log name
$eventSource = "CustomScriptEvent"
$logName = "Application"

function Install-VmFeatures {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $VmRole,
        [Parameter(Mandatory=$true)]
        [string] $AdminName,
        [Parameter(Mandatory=$true)]
        [securestring] $AdminPassword,
        [Parameter(Mandatory=$true)]
        [string] $DomainName,
        [Parameter(Mandatory=$true)]
        [string] $DomainBiosName
    )

    Begin {
        Write-Host 'Starting to install Windows features needed on this server.'
    }

    Process {
        [pscredential] $Credential = New-Object System.Management.Automation.PSCredential($AdminName, $AdminPassword)
            try {
                Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/PowerShell-7.3.2-win-x64.msi' -OutFile 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi'
                msiexec.exe /package 'c:\windows\temp\PowerShell-7.3.2-win-x64.msi' /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1
                Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True
                Enable-PSRemoting -SkipNetworkProfileCheck -Force
                Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
                Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
            }
            catch {
                # If an error occurs, log it to the Windows event log
                $eventLog = New-Object System.Diagnostics.EventLog($logName)
                $eventLog.Source = $eventSource
                $eventLog.WriteEntry($_.Exception.Message, [System.Diagnostics.EventLogEntryType]::Error)   
                Write-Error $_.Exception.Message
            }
    
            if ($vmrole -eq 'domain' || $vmrole -eq 'domaincontroller' || $vmrole -eq 'dc') {
                try {
                    Install-WindowsFeature -Name AD-Domain-Services, DNS -Credential $Credential -IncludeAllSubFeature -IncludeManagementTools
                    Import-Module ADDSDeployment 
                    Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $DomainBiosName `
                    -DomainMode 'WinThreshold' `
                    -ForestMode 'WinThreshold' `
                    -InstallDns `
                    -SafeModeAdministratorPassword $Credential.Password `
                    -NoRebootOnCompletion `
                    -Force
                }
                catch {
                    # If an error occurs, log it to the Windows event log
                    $eventLog = New-Object System.Diagnostics.EventLog($logName)
                    $eventLog.Source = $eventSource
                    $eventLog.WriteEntry($_.Exception.Message, [System.Diagnostics.EventLogEntryType]::Error)
                    Write-Error $_.Exception.Message
                }
            }
            else {
                try {
                    Install-WindowsFeature -Name Failover-Clustering, FS-FileServer, FS-DFS-Namespace, FS-DFS-Replication, FS-DFS-Service -IncludeManagementTools -Credential $credential
                }
                catch {
                # If an error occurs, log it to the Windows event log
                $eventLog = New-Object System.Diagnostics.EventLog($logName)
                $eventLog.Source = $eventSource
                $eventLog.WriteEntry($_.Exception.Message, [System.Diagnostics.EventLogEntryType]::Error)
                Write-Error $_.Exception.Message
            }
        }
    }
    
    End {
        Write-Host "Installation of Windows features completed..."
    }
}
