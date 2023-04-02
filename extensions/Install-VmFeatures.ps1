param(
    [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $Variables
)

Write-Output $Variables
Write-Error $Variables

Write-Host 'Hello world'
<#
############################################################################################################
# Function Definitions
############################################################################################################

# Function to simplify the creation of an event log entry.
Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $Message,
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] [string] $Source = "CustomScriptEvent",
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] [string] $EventLogName = "Application",
        [Parameter(Mandatory = $false)] [System.Diagnostics.EventLogEntryType] [ValidateNotNullOrEmpty()] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    # Check whether the event source exists, and create it if it doesn't exist.
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) { [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName) }

    $log = New-Object System.Diagnostics.EventLog($EventLogName)
    $log.Source = $Source
    $log.WriteEntry($Message, $EntryType)

    # Set log directory and file
    $logDirectory = "C:\\Temp\\CseLogs"
    $logFile = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd').log"

    # Create the log directory if it does not exist
    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory | Out-Null
    }

    # Prepare log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    try {
        # Write log entry to the file
        Add-Content -Path $logFile -Value $logEntry
        Write-Host $logEntry
        Write-Output $logEntry
    }
    catch {
        Write-Host "Failed to write log entry to file: $($_.Exception.Message)"
        Write-Error "Failed to write log entry to file: $($_.Exception.Message)"
        thorw $_.Exception
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

# Function to install specified Windows Features.
Function Install-RequiredWindowsFeatures {
    param(
        [Parameter(Mandatory = $true)] [System.Collections.Generic.List[string]] $FeatureList
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
                Write-EventLog -Message "Windows Feature $feature has been installed." -EntryType Information
            }
            catch {
                Write-EventLog -Message "An error occurred while installing Windows Feature $feature (Error: $($_.Exception.Message))." -EntryType Error
            }
        }
    }
    else {
        Write-EventLog -Message "Nothing to install. All required features are installed." -EntryType Information
    }
}

# Function to check if PowerShell 7 is installed. If not, install it and install the Az module.
Function Install-PowerShellWithAzModules {
    param(
        [Parameter(Mandatory = $true)] [string] $Url,
        [Parameter(Mandatory = $true)] [string] $MsiPath
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
            Get-WebResourcesWithRetries -SourceUrl $url `
                -DestinationPath $msiPath
            
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $msiPath /quiet /norestart /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -ErrorAction SilentlyContinue
            Write-EventLog -Message "Installing PowerShell 7 completed." -EntryType Information
        }
        else {
            # if msi installer exists, then just install in.
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $Msi /quiet /norestart /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -ErrorAction SilentlyContinue
            Write-EventLog -Message "Installing PowerShell 7 completed." -EntryType Information
        }

        # contuning to install the Az modules.
        if ($null -eq (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet `
                -Force `
                -ErrorAction SilentlyContinue
        }
        else {
            Write-EventLog -Message "NuGet Package Provider is found. Skipping the installation." `
                -EntryType Information
        }
        
        Write-EventLog -Message "Installing the Az module." `
            -EntryType Information

        # Ensure the Az module is installed
        if ($null -eq (Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue)) { 
            Install-Module -Name Az `
                -Force `
                -AllowClobber `
                -Scope AllUsers `
                -ErrorAction SilentlyContinue 
        
            Write-EventLog -Message "Az Modules have been installed." `
                -EntryType Information
        }
        else {
            Write-EventLog -Message "Az Modules are found. Skipping the installation." `
                -EntryType Information
        }

        # remove the AzureRM module if it exists
        if (Get-Module -ListAvailable -Name AzureRM) { 
            Uninstall-Module -Name AzureRM `
                -Force `
                -ErrorAction SilentlyContinue 
        }
    }
    catch {
        Write-EventLog -Message "Error installing PowerShell 7 with Az Modules (Error: $($_.Exception.Message))." -EntryType Error
    }
}

# Function to download a file from a URL and retry if the download fails.
Function Get-WebResourcesWithRetries {
    param (
        [Parameter(Mandatory = $true)] [string] $SourceUrl,
        [Parameter(Mandatory = $true)] [string] $DestinationPath,
        [Parameter(Mandatory = $false)] [int] $MaxRetries = 5,
        [Parameter(Mandatory = $false)] [int] $RetryIntervalSeconds = 1
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

            $response = Invoke-WebRequest -Uri $SourceUrl `
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
            Write-EventLog -Message "Error downloading file from $SourceUrl (Error: $($_.Exception.Message))" -EntryType Error
            Start-Sleep -Seconds (2 * $retryCount)
        }
    }

    if (-not $completed) { 
        Write-EventLog -Message "Failed to download file from $SourceUrl." -EntryType Error
        throw "Failed to download file from $SourceUrl."
    } 

    else {
        Write-EventLog -Message "Download of $SourceUrl completed successfully." -EntryType Information
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
            -EntryType Information

        Import-Module ADDSDeployment

        Install-ADDSForest -DomainName $DomainName `
            -DomainNetbiosName $DomainNetBiosName `
            -DomainMode 'WinThreshold' `
            -ForestMode 'WinThreshold' `
            -InstallDns `
            -SafeModeAdministratorPassword $Credential.Password `
            -Force

        Write-EventLog -Message 'Active Directory Domain Services has been configured.' -EntryType information
    }
    catch {
        Write-EventLog -Message "An error occurred while installing Active Directory Domain Services (Error: $($_.Exception.Message))" -EntryType Error
    }
}

# Function to set extra VM configurations
Function Set-DefaultVmEnvironment {
    param(
        [Parameter(Mandatory = $true)] [string] $TempFolderPath,
        [Parameter(Mandatory = $true)] [string] $TimeZone
    )
    if (-not (Test-Path -Path $TempFolderPath)) { 
        New-Item -ItemType Directory -Path $TempFolderPath 
    }

    # Disable Internet Explorer Enchanced Security features on Windows
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -PropertyType DWORD -Force | Out-Null

    Set-TimeZone -Id $TimeZone
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
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
                Direction   = 'Inbound'
                Protocol    = 'TCP'
                LocalPort   = @(5985, 5986)
                Enabled     = $true
            },
            @{
                DisplayName = 'ICMP'
                Direction   = 'Inbound'
                Protocol    = 'ICMPv4'
                Enabled     = $true
            },
            @{
                DisplayName = 'WinRM'
                Direction   = 'Inbound'
                Protocol    = 'TCP'
                LocalPort   = @(5985, 5986)
                Enabled     = $true
            }
        ))

    if ($IsActiveDirectory -eq $true) {
        $ruleList.Add(@(
                @{
                    DisplayName = 'DNS'
                    Direction   = 'Inbound'
                    Protocol    = 'UDP'
                    LocalPort   = 53
                    Enabled     = $true
                },
                @{
                    DisplayName = 'DNS'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = 53
                    Enabled     = $true
                },
                @{
                    DisplayName = 'Kerberos'
                    Direction   = 'Inbound'
                    Protocol    = 'UDP'
                    LocalPort   = 88
                    Enabled     = $true
                },
                @{
                    DisplayName = 'Kerberos'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = 88
                    Enabled     = $true
                }
            ))
    }
    else {
        $ruleList.Add(@(
                @{
                    DisplayName = 'SMB'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = 445
                    Enabled     = $true
                },
                @{
                    DisplayName = 'NFS'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = 2049
                    Enabled     = $true
                },
                @{
                    DisplayName = 'SQL Server'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = @(1433, 1434)
                    Enabled     = $true
                },
                @{
                    DisplayName = 'iSCSI Target Server'
                    Direction   = 'Inbound'
                    Protocol    = 'TCP'
                    LocalPort   = 3260
                    Enabled     = $true
                },
                @{
                    DisplayName = 'TFTP Server'
                    Direction   = 'Inbound'
                    Protocol    = 'UDP'
                    LocalPort   = 69
                    Enabled     = $true
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
                $params = @{
                    DisplayName = $ruleName
                    Direction   = $rule.Direction
                    Protocol    = $rule.Protocol
                    Enabled     = if ($rule.Enabled) { 'True' } else { 'False' }
                }
                if ($rule.LocalPort) { $params.LocalPort = $rule.LocalPort }
                New-NetFirewallRule @params -ErrorAction SilentlyContinue
                Write-EventLog -Message "Created Windows Firewall rule: $ruleName" -EntryType Information
            } 
        }
    }
}

############################################################################################################
# Execution Body
############################################################################################################

# $Variables = '{"vm_role":"cluster", "admin_name":"pashim", "admin_password":"Roman@2013!2015", "domain_name":"neostation.org", "domain_netbios_name":"NEOSTATION", "domain_server_ip":"172.16.0.100", "cluster_name":"mscs-cluster", "cluster_ip":"172.16.1.50", "cluster_role_ip": "172.16.1.100", "cluster_network_name": "Cluster Network 1", "cluster_probe_port": "61800", "sa_name": "mscskrcommonstoragespace", "sa_key": "8AOz8Rjj2n4/aao2KdMf5YDpIzB6wfBrAZf4KpQzoEU/33EZ7GGgHlvxpCFBOTl2wMWDRxNe6bm++AStFbGMIw=="}'
$values = ConvertFrom-Json -InputObject $Variables
$AdminName = $values.admin_name
$Secret = $values.admin_password
$DomainName = $values.domain_name
$DomainNetbiosName = $values.domain_netbios_name

############################################################################################################
# Variable Definitions
############################################################################################################

$tempPath = "C:\\Temp"
$msi = "PowerShell-7.3.2-win-x64.msi"
$msiPath = "$tempPath\\$msi"
$powershellUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/$msi"
$timeZone = "Singapore Standard Time"
$scriptUrl = "https://raw.githubusercontent.com/apacdev/mscs-storage-cluster/main/extensions/join-mscs-domain.ps1"
$scriptPath = "C:\\Temp\\join-mscs-domain.ps1"
$adminSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($AdminName, $adminSecret)

############################################################################################################

try {
        Write-EventLog -Message "Starting installation of roles and features (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." -EntryType Information
        Set-DefaultVmEnvironment -TempFolderPath $tempPath -TimeZone $timeZone
        Install-PowerShellWithAzModules -Url $powershellUrl -Msi $msiPath
    
    # Install required Windows Features for Domain Controller Setup
    if ($Role -match '^(?=.*(?:domain|dc|ad|dns|domain-controller|ad-domain|domaincontroller|ad-domain-server|ad-dns|dc-dns))(?!.*(?:cluster|cluster-node|failover-node|failover|node)).*$') {

        Set-RequiredFirewallRules -IsActiveDirectory $true 
        
        if (-not (Test-WindowsFeatureInstalled -FeatureName "AD-Domain-Services")) {
            Install-RequiredWindowsFeatures -FeatureList @("AD-Domain-Services", "RSAT-AD-PowerShell", "DNS", "NFS-Client")
            Set-ADDomainServices -DomainName $DomainName -DomainNetBiosName $DomainNetbiosName -Credential $credential
        }
        else {
            Set-ADDomainServices -DomainName $DomainName -DomainNetBiosName $DomainNetbiosName -Credential $credential
        }
    }
    else {
        # Install required Windows Features for Failover Cluster and File Server Setup
        Set-RequiredFirewallRules -IsActiveDirectory $false
        Install-RequiredWindowsFeatures -FeatureList @("Failover-Clustering", "RSAT-AD-PowerShell", "FileServices", "FS-FileServer", "FS-iSCSITarget-Server", "FS-NFS-Service", "NFS-Client", "TFTP-Client", "Telnet-Client")
        Get-WebResourcesWithRetries -SourceUrl $scriptUrl -DestinationPath $scriptPath -MaxRetries 5 -RetryIntervalSeconds 1
        Write-EventLog -Message "Starting scheduled task to join the cluster to the domain (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." -EntryType Information
        # action: join-mscs-domain.ps1
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"& '$scriptPath' -Variables $values`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $trigger.EndBoundary = (Get-Date).ToUniversalTime().AddMinutes(30).ToString("o")
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName "Join-MscsDomain" -Action $action -Trigger $trigger -Settings $settings -User $AdminName -RunLevel Highest -Force
        Write-EventLog -Message "Scheduled task to join the cluster to the domain created (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." -EntryType Information
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message -EntryType Error 
}

#>