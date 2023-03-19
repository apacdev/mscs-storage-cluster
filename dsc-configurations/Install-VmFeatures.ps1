SuppressMessage('PSAvoidUsingPlainTextForPassword', 'Parameter should not use String type')
<#
.LICENSE
Copyright (c) Microsoft Corporation. All rights reserved.

.AUTHOR
patrick.shim@live.co.kr (Patrick Shim)

.VERSION
1.0.0.3

.SYNOPSIS
Installs PowerShell 7 and necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. Logs events to the Windows event log and catches any exceptions that occur.

.DESCRIPTION
This script installs PowerShell 7 on a Windows machine if it's not already installed, and then installs the necessary roles and features for either a domain controller or a node in a Windows Failover Cluster. The script logs events to the Windows event log using a custom event source, and catches and logs any exceptions that occur during the execution of the script.

.PARAMETER VmName
Specifies the name of the virtual machine.

.PARAMETER VmRole
Specifies the role of the virtual machine (`domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node).

.PARAMETER AdminName
Specifies the name of the administrator account for the domain.

.PARAMETER AdminPassword
Specifies the password for the administrator account.

.PARAMETER DomainName
Specifies the name of the domain.

.PARAMETER DomainNetBiosName
Specifies the NetBIOS name of the domain.

.PARAMETER DomainServerIpAddress
Specifies the Private IP Address of the domain server.

.EXAMPLE
.\InstallRolesAndFeatures.ps1 -VmRole domaincontroller -AdminName Admin -AdminPassword P@ssw0rd -DomainName contoso.com -DomainNetBiosName CONTOSO -DomainServerIpAddress

.NOTES
- This script requires elevated privileges to run, i.e., as an administrator.
- The `VmRole` parameter must be one of the following: `domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node.
- The `AdminName` and `AdminPassword` parameters must specify the name and password of an administrator account for the domain.
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $VmRole,

    [Parameter(Mandatory = $true)]
    [string] $AdminName,
        
    [Parameter(Mandatory = $true)]
    [string] $AdminPassword,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
        
    [Parameter(Mandatory = $true)]
    [string] $DomainNetBiosName,
    
    [Parameter(Mandatory = $true)]
    [string] $DomainServerIpAddress
)

# Function to check if Az Modules are installed.
Function Test-AzModulesInstalled {
    if (Get-Module -Name Az -ListAvailable) {
        return $true
    } else {
        return $false
    }
}
# Function to check if the VM has the specified Windows Feature installed.  Returns true if the feature is installed, false otherwise.
Function Test-WindowsFeatureInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FeatureName
    )

    $feature = Get-WindowsFeature -Name $FeatureName
    if ($feature.InstallState -ne "Installed") { 
        return $false 
    }
    else { 
        return $true 
    }
}

# Function to check if Domain Controller is available
Function Test-DcAvailability {
    param (
        [Parameter(Mandatory = $true)]
        [String] $ServerIpAddress
    )

    if (Test-Connection -ComputerName $ServerIpAddress -Count 1 -Quiet) { 
        try {
            Get-ADDomainController -Server $ServerIpAddress
            Write-EventLog -Message "Domain Controller is available." -Source $EventSource -EventLogName $EventLogName -EntryType Information
            return $true

        } catch {
            Write-EventLog -Message "Domain Controller is not available (Error: $($_.Exception.Message))" -Source $EventSource -EventLogName $EventLogName -EntryType Error
            return $false
        }
    } else {
        return $false
    }
}

# Function to wait for Domain Controller availability
Function Wait-DcAvailability {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ServerIpAddress,
        [int] $TimeoutInSeconds = 60,
        [int] $IntervalInSeconds = 1
    )
    
    $startTime = Get-Date
    
    while ((Get-Date) -lt ($startTime).AddSeconds($TimeoutInSeconds)) {
            
        if (Test-DcAvailability -ServerIpAddress $ServerIpAddress) { 
            return $true
        }
        Start-Sleep -Seconds $IntervalInSeconds
    }
    return $false
}

# Function to install specified Windows Features.
Function Install-RequiredWindowsFeatures {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[string]] $FeatureList
    )
    
    $toInstallList = New-Object System.Collections.Generic.List[string]
    $features = Get-WindowsFeature $FeatureList -ErrorAction SilentlyContinue
    
    foreach ($feature in $features) {
        if ($feature.InstallState -ne 'Installed') { 
            # build a list of features to install
            $toInstallList.Add($feature.Name)
        }
    }

    if ($toInstallList.count -gt 0) {
        foreach ($feature in $toInstallList) {
            try {
                Install-WindowsFeature -Name $feature -IncludeManagementTools -IncludeAllSubFeature
                Write-EventLog -Message "Windows Feature $feature has been installed." `
                    -Source $EventSource `
                    -EventLogName $EventLogName `
                    -EntryType Information
            }
            catch {
                Write-EventLog -Message "An error occurred while installing Windows Feature $feature (Error: $($_.Exception.Message))." `
                    -Source $EventSource `
                    -EventLogName $EventLogName `
                    -EntryType Error
            }
        }
    }
    else {
        Write-EventLog -Message "Nothing to install. All required features are installed." `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Information
    }
}

# Function to check if PowerShell 7 is installed. If not, install it and install the Az module.
Function Install-PowerShellWithAzModules {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url,
        [Parameter(Mandatory = $true)]
        [string] $MsiPath
    )
    try {
        # check if a temp directory for a download exists. if not, create it.
        if (-not (Test-Path -Path $tempPath)) { 
            New-Item -Path $tempPath `
                -ItemType Directory `
                -Force 
        }
        
        # check if msi installer exists. if yes then skip the download and go to the installation.
        if (-not (Test-Path -Path $msiPath)) {
            Get-WebResourcesWithRetries -SrouceUrl $url `
                -DestinationPath $msiPath
            
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $msiPath /quiet /norestart /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -ErrorAction SilentlyContinue
            
            Write-EventLog -Message "Installing PowerShell 7 completed." `
                -Source $EventSource `
                -EventLogName $EventLogName `
                -EntryType Information
        }
        else {
            # if msi installer exists, then just install in.
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $Msi /quiet /norestart /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -ErrorAction SilentlyContinue
            Write-EventLog -Message "Installing PowerShell 7 completed." `
                -Source $EventSource `
                -EventLogName $EventLogName `
                -EntryType Information
        }

        # contuning to install the Az modules.
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet `
                -Force `
                -ErrorAction SilentlyContinue
        }
        
        Write-EventLog -Message "Installing the Az module." `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Information

        if (-not (Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue)) { 
            Install-Module -Name Az `
                -Force `
                -Scope AllUsers `
                -ErrorAction SilentlyContinue 
        }

        Write-EventLog -Message "PowerShell 7 and Az Modules have been installed." `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Information

        # remove the AzureRM module if it exists
        if (Get-Module -ListAvailable -Name AzureRM) { 
            Uninstall-Module -Name AzureRM `
                -Force `
                -ErrorAction SilentlyContinue 
        }

    } catch {
        Write-EventLog -Message "Error installing PowerShell 7 with Az Modules (Error: $($_.Exception.Message))" `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Error
    }
}

# Function to download a file from a URL and retry if the download fails.
Function Get-WebResourcesWithRetries {
    param (
        [Parameter(Mandatory = $true)]
        [string] $SrouceUrl,

        [Parameter(Mandatory = $true)]
        [string] $DestinationPath,

        [int] $MaxRetries = 5
    )

    $retryCount = 0
    $completed = $false
    $response = $null

    while (-not $completed -and $retryCount -lt $MaxRetries) {
        try {
            $fileExists = Test-Path $DestinationPath
            $headers = @{}

            if ($fileExists) {
                $fileLength = (Get-Item $DestinationPath).Length
                $headers["Range"] = "bytes=$fileLength-"
            }

            $response = Invoke-WebRequest -Uri $Url `
                -Headers $headers `
                -OutFile $DestinationPath `
                -UseBasicParsing `
                -PassThru `
                -ErrorAction Stop

            if ($response.StatusCode -eq 206 -or $response.StatusCode -eq 200) { 
                $completed = $true 
            }
            else { 
                $retryCount++ 
            }
        }
        catch {
            $retryCount++
            Start-Sleep -Seconds (2 * $retryCount)
        }
    }

    if (-not $completed) { 
        Write-EventLog -Message "Failed to download file from $Url" `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Error
        } 

    else { Write-EventLog -Message "Download of $Url completed successfully" `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Information
    }
}

# Function to configure the domain controller.
Function Set-ADDomainServices {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DomainName,
        [Parameter(Mandatory = $true)]
        [string] $DomainNetBiosName,
        [Parameter(Mandatory = $true)]
        [pscredential] $Credential
    )
    try {        
        Write-EventLog -Message 'Configuring Active Directory Domain Services...' `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Information

        Import-Module ADDSDeployment

        Install-ADDSForest -DomainName $DomainName `
            -DomainNetbiosName $DomainNetBiosName `
            -DomainMode 'WinThreshold' `
            -ForestMode 'WinThreshold' `
            -InstallDns `
            -SafeModeAdministratorPassword $Credential.Password `
            -Force

        Write-EventLog -Message 'Active Directory Domain Services has been configured.' `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType information
    }
    catch {
        Write-EventLog -Message "An error occurred while installing Active Directory Domain Services (Error: $($_.Exception.Message))" `
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Error
    }
}

# Function to set extra VM configurations
Function Set-DefaultVmEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string] $TempFolderPath,
        [Parameter(Mandatory = $true)]
        [string] $TimeZone
    )
    if (-not (Test-Path -Path $TempFolderPath)) { 
        New-Item -ItemType Directory `
            -Path $TempFolderPath 
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" `
        -Name "IsInstalled" `
        -Value 0
    Set-TimeZone -Id $TimeZone
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
}

# Function to set the common Windows Firewall rules
Function Set-RequiredFirewallRules {
    param(
        [Parameter(Mandatory = $true)]
        [bool] $IsActiveDirectory
    )

    $ruleList = [System.Collections.ArrayList] @()
    
    $ruleList.Add(@(
        @{
            DisplayName = 'PowerShell Remoting'
            Direction = 'Inbound'
            Protocol = 'TCP'
            LocalPort = @(5985, 5986)
            Enabled = $true
        },
        @{
            DisplayName = 'ICMP'
            Direction = 'Inbound'
            Protocol = 'ICMPv4'
            Enabled = $true
        },
        @{
            DisplayName = 'WinRM'
            Direction = 'Inbound'
            Protocol = 'TCP'
            LocalPort = @(5985, 5986)
            Enabled = $true
        }
    ))

    if ($IsActiveDirectory -eq $true) {
        $ruleList.Add(@(
            @{
                DisplayName = 'DNS'
                Direction = 'Inbound'
                Protocol = 'UDP'
                LocalPort = 53
                Enabled = $true
            },
            @{
                DisplayName = 'DNS'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = 53
                Enabled = $true
            },
            @{
                DisplayName = 'Kerberos'
                Direction = 'Inbound'
                Protocol = 'UDP'
                LocalPort = 88
                Enabled = $true
            },
            @{
                DisplayName = 'Kerberos'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = 88
                Enabled = $true
            }
        ))
    } else {
        $ruleList.Add(@(
            @{
                DisplayName = 'SMB'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = 445
                Enabled = $true
            },
            @{
                DisplayName = 'NFS'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = 2049
                Enabled = $true
            },
            @{
                DisplayName = 'SQL Server'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = @(1433, 1434)
                Enabled = $true
            },
            @{
                DisplayName = 'iSCSI Target Server'
                Direction = 'Inbound'
                Protocol = 'TCP'
                LocalPort = 3260
                Enabled = $true
            },
            @{
                DisplayName = 'TFTP Server'
                Direction = 'Inbound'
                Protocol = 'UDP'
                LocalPort = 69
                Enabled = $true
            }
        ))
    }

    # Configure Windows Firewall
    $ruleList | ForEach-Object {
        $_ | ForEach-Object {
            $rule = $_
            $ruleName = $rule.DisplayName
            $ruleExists = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if (-not $ruleExists) {
                $params  = @{
                    DisplayName = $ruleName
                    Direction   = $rule.Direction
                    Protocol    = $rule.Protocol
                    Enabled     = if ($rule.Enabled) { 'True' } else { 'False' }
                }
                if ($rule.LocalPort) { $params.LocalPort = $rule.LocalPort }
                New-NetFirewallRule @params -ErrorAction SilentlyContinue
                Write-EventLog -Message "Created Windows Firewall rule: $ruleName" -Source $EventSource -EventLogName $EventLogName -EntryType Information
            } 
        }
    }
}

# Function to check if the VM is already joined to the domain.
Function Join-DomainIfNotJoined {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DomainName,
        [Parameter(Mandatory = $true)]
        [string] $DomainServerIpAddress,
        [Parameter(Mandatory = $true)]
        [pscredential] $Credential,
        [Parameter(Mandatory = $false)]
        [bool] $Reboot = $true
    )

    try {
        $curruentDomain = Get-WmiObject -Class Win32_ComputerSystem `
            -ComputerName $DomainServerIpAddress `
            -Credential $Credential

        if ($curruentDomain.Domain -ne $DomainName) {
            Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) `
                -ServerAddresses $DomainServerIpAddress

            Write-EventLog -Message 'Joining the computer to the domain.' `
                -Source $EventSource `
                -EventLogName $EventLogName `
                -EntryType Information

            Add-Computer -DomainName $DomainName `
                -Credential $Credential `
                -Restart:$Reboot

            Write-EventLog -Message 'Joining the computer to the domain has completed.' `
                -Source $EventSource `
                -EventLogName $EventLogName `
                -EntryType Information
        } else {
            Write-EventLog -Message 'The computer is already joined to the domain.' `
                -Source $EventSource `
                -EventLogName $EventLogName `
                -EntryType Information
        }
    }
    catch {
        Write-EventLog -Message $_.Exception.Message 
            -Source $EventSource `
            -EventLogName $EventLogName `
            -EntryType Error
    }
}

# Function to simplify the creation of an event log entry.
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

############################################################################################################
# Variable Definitions
############################################################################################################

$tempPath = "C:\\Temp"
$msi = "PowerShell-7.3.2-win-x64.msi"
$msiPath = "$tempPath\\$msi"
$url = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/$msi"
$timeZone = "Singapore Standard Time"
$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $AdminPassword -AsPlainText -Force))
$EventSource = "CustomScriptEvent"
$EventLogName = "Application"

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
}

############################################################################################################
# Execution Body
############################################################################################################

try {
    Write-EventLog -Message "Starting installation of roles and features (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." `
        -Source "CustomScriptEvent" `
        -EventLogName "Application"
    
    Set-DefaultVmEnvironment -TempFolderPath $tempPath -TimeZone $timeZone

    Install-PowerShellWithAzModules -Url $url -Msi $msiPath

    # Install required Windows Features for Domain Controller Setup
    if ($VmRole -in ('domain', 'dc', 'ad', 'dns', 'domain-controller', 'ad-dns', 'dc-dns') ) {
        Set-RequiredFirewallRules -IsActiveDirectory $true 

        if (-not (Test-WindowsFeatureInstalled -FeatureName "AD-Domain-Services")) {
            Install-RequiredWindowsFeatures -FeatureList @("AD-Domain-Services", "RSAT-AD-PowerShell","DNS","NFS-Client")
            Set-ADDomainServices -DomainName $DomainName `
                -DomainNetBiosName $DomainNetbiosName `
                -DomainServerIpAddress $DomainServerIpAddress `
                -Credential $Credential
        } else {
            Set-ADDomainServices -DomainName $DomainName `
                -DomainNetBiosName $DomainNetbiosName `
                -DomainServerIpAddress $DomainServerIpAddress `
                -Credential $Credential
        }
    } else {
    # Install required Windows Features for Failover Cluster and File Server Setup
        Set-RequiredFirewallRules -IsActiveDirectory $false

        Install-RequiredWindowsFeatures -FeatureList @("Failover-Clustering", "RSAT-AD-PowerShell", "FileServices", "FS-FileServer", "FS-iSCSITarget-Server", "FS-NFS-Service", "NFS-Client", "TFTP-Client", "Telnet-Client")

        $ready = Wait-DCAvailability -ServerIpAddress $DomainServerIpAddress `
            -TimeoutInSeconds 600 `
            -IntervalInSeconds 10

        if ($ready) {
            Join-DomainIfNotJoined -DomainName $DomainName `
                -Credential $Credential `
                -DomainServerIp $DomainServerIpAddress `
                -Reboot $true

            Write-EventLog -Message "Installation of roles and features completed (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." `
                -Source "CustomScriptEvent" `
                -EventLogName "Application"
        }
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message `
        -Source $EventSource `
        -EventLogName $EventLogName `
        -EntryType Error
}
