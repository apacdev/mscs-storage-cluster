<#
.DISCLAIMER
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.LICENSE
Copyright (c) Microsoft Corporation. All rights reserved.

.AUTHOR
patrick.shim@live.co.kr (Patrick Shim)

.VERSION
1.0.0.3

.SYNOPSIS
Custom Script Extension to install applications and Windows Features on Windows VMs.

.DESCRIPTION
This script configures each VMs per the role of the VMs in a fully automated way. The script will install the following applications and Windows Features on the VMs: 
a. Common - PowerShell 7 and Az Modules 
b. 1 x AD Domain Controller - Active Directory Domain Services, DNS Server
c. 2 x Node Servers - Failover Clustering, File Server Services such as NFS, SMB, and iSCSI

.PARAMETER ServerList
An array that contains the VM names and IP addresses. It is passed as a parameter to the remote script.

.PARAMETER VmName
Specifies the name of the virtual machine.

.PARAMETER VmRole
Specifies the role of the virtual machine (`domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node).

.PARAMETER AdminName
Specifies the name of the administrator account for the domain.

.PARAMETER Secret
Specifies the password for the administrator account.

.PARAMETER DomainName
Specifies the name of the domain.

.PARAMETER DomainNetBiosName
Specifies the NetBIOS name of the domain.

.PARAMETER DomainServerIpAddress
Specifies the Private IP Address of the domain server.

.EXAMPLE
.\InstallRolesAndFeatures.ps1 -ServerList @(@("server-01", "192.168.1.1")) -VmRole domaincontroller -AdminName Admin -adminSecret P@ssw0rd -DomainName contoso.com -DomainNetBiosName CONTOSO -DomainServerIpAddress

.NOTES
- This script is tested on Windows Server 2022 VMs.
- This script requires elevated privileges to run, i.e., as an administrator.
- The `ServerList` parameter has default values for testing purposes.
- The `VmRole` parameter must be one of the following: `domain`, `domaincontroller`, or `dc` for a domain controller; anything else for a node.
- The `AdminName` and `-adminSecret` parameters must specify the name and password of an administrator account for the domain.
#>

param(
    [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)] [string] $VmRole,
    [Parameter(Mandatory = $true)] [string] $VmName,
    [Parameter(Mandatory = $true)] [string] $AdminName,
    [Parameter(Mandatory = $true)] [string] $Secret,
    [Parameter(Mandatory = $true)] [string] $DomainName,
    [Parameter(Mandatory = $true)] [string] $DomainNetBiosName,
    [Parameter(Mandatory = $true)] [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)] [array]  $ServerList
)

############################################################################################################
# Variable Definitions
############################################################################################################

$tempPath = "C:\\Temp"
$msi = "PowerShell-7.3.2-win-x64.msi"
$msiPath = "$tempPath\\$msi"
$powershellUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.2/$msi"
$timeZone = "Singapore Standard Time"
$adminSecret = ConvertTo-SecureString -String $Secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($AdminName, $adminSecret)
$eventSource = "CustomScriptEvent"
$eventLogName = "Application"
# $ServerList = @(@("mscswvm-01", "172.16.0.100"), @("mscswvm-02", "172.16.1.101"), @("mscswvm-03", "172.16.1.102"))
# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $eventLogName)
}

############################################################################################################
# Function Definitions
############################################################################################################

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
                    -Source $eventSource `
                    -EventLogName $eventLogName `
                    -EntryType Information
            }
            catch {
                Write-EventLog -Message "An error occurred while installing Windows Feature $feature (Error: $($_.Exception.Message))." `
                    -Source $eventSource `
                    -EventLogName $eventLogName `
                    -EntryType Error
            }
        }
    }
    else {
        Write-EventLog -Message "Nothing to install. All required features are installed." `
            -Source $eventSource `
            -EventLogName $eventLogName `
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
                -Source $eventSource `
                -EventLogName $eventLogName `
                -EntryType Information
        }
        else {
            # if msi installer exists, then just install in.
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $Msi /quiet /norestart /passive ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait -ErrorAction SilentlyContinue
            Write-EventLog -Message "Installing PowerShell 7 completed." `
                -Source $eventSource `
                -EventLogName $eventLogName `
                -EntryType Information
        }

        # contuning to install the Az modules.
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet `
                -Force `
                -ErrorAction SilentlyContinue
        }
        
        Write-EventLog -Message "Installing the Az module." `
            -Source $eventSource `
            -EventLogName $eventLogName `
            -EntryType Information

        # Ensure the Az module is installed
        if (-not (Get-Module -Name Az -ListAvailable -ErrorAction SilentlyContinue)) { 
            Install-Module -Name Az `
                -Force `
                -AllowClobber `
                -Scope AllUsers `
                -ErrorAction SilentlyContinue 
        }

        Write-EventLog -Message "PowerShell 7 and Az Modules have been installed." `
            -Source $eventSource `
            -EventLogName $eventLogName `
            -EntryType Information

        # remove the AzureRM module if it exists
        if (Get-Module -ListAvailable -Name AzureRM) { 
            Uninstall-Module -Name AzureRM `
                -Force `
                -ErrorAction SilentlyContinue 
        }
    }
    catch {
        Write-EventLog -Message "Error installing PowerShell 7 with Az Modules (Error: $($_.Exception.Message))" `
            -Source $eventSource `
            -EventLogName $eventLogName `
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
            -Source $eventSource `
            -EventLogName $eventLogName `
            -EntryType Error
    } 

    else {
        Write-EventLog -Message "Download of $Url completed successfully" `
            -Source $eventSource `
            -EventLogName $eventLogName `
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
            -Source $eventSource `
            -EventLogName $eventLogName `
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
            -Source $eventSource `
            -EventLogName $eventLogName `
            -EntryType information
    }
    catch {
        Write-EventLog -Message "An error occurred while installing Active Directory Domain Services (Error: $($_.Exception.Message))" `
            -Source $eventSource `
            -EventLogName $eventLogName `
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
        New-Item -ItemType Directory -Path $TempFolderPath 
    }

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
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
                Write-EventLog -Message "Created Windows Firewall rule: $ruleName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
            } 
        }
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
        [string] $eventLogName,

        [Parameter(Mandatory = $false)]
        [System.Diagnostics.EventLogEntryType] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    $log = New-Object System.Diagnostics.EventLog($eventLogName)
    $log.Source = $Source
    $log.WriteEntry($Message, $EntryType)
}

Function Join-Domain {
    param (
        [Parameter(Mandatory=$true)] [string] $DomainName,
        [Parameter(Mandatory=$true)] [string] $DomainServerIpAddress,
        [Parameter(Mandatory=$true)] [pscredential] $Credential,
        [Parameter()] [int] $MaxRetries = 10,
        [Parameter()] [int] $RetryIntervalSeconds = 30
    )
    
    Write-EventLog -Message "Joining domain $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information

    # Join domain
    Write-EventLog -Message "Setting DNS server on this server to $DomainServerIpAddress" -Source $eventSource -EventLogName $eventLogName -EntryType Information
    Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
                
    $retries = 0
    
    # Wait for network connectivity to the domain server
    while ($retries -lt $MaxRetries) {
        if ((Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
            Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress established." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            
            # Check if the domain controller is ready to accept a computer join
            Add-Computer -DomainName $DomainName `
                    -Credential $Credential `
                    -Restart `
                    -Force

            Write-EventLog -Message "Joined domain $DomainName. Now restarting the computer." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            return
        }
        $retries++
        Write-EventLog -Message "Unable to join domain. Retrying in $RetryIntervalSeconds seconds..." -Source $eventSource -EventLogName $eventLogName -EntryType Information
        Start-Sleep -Seconds $RetryIntervalSeconds
    }
    Write-EventLog -Message "Failed to join domain after $MaxRetries retries." -Source $eventSource -EventLogName $eventLogName -EntryType Error
}

Function Set-MSClusteringService { 
            
    New-Cluster -Name $ClusterName `
        -Node $env:computername `
        -StaticAddress $ClusterIp `
        -NoStorage `
        -Force

    Add-ClusterNode -Cluster $ClusterName `
        -Node $env:computername `
        -NodeCredential $credential `
        -Force

}

############################################################################################################
# Execution Body
############################################################################################################

Write-EventLog -Message "Starting installation of roles and features (timestamp: $((Get-Date).ToUniversalTime().ToString("o")))." `
    -Source $eventSource `
    -EventLogName $eventLogName `
    -EntryType Information

try {    
    Set-DefaultVmEnvironment -TempFolderPath $tempPath -TimeZone $timeZone
    Install-PowerShellWithAzModules -Url $powershellUrl -Msi $msiPath
    
  #  $adminSecret = ConvertTo-SecureString -String $adminSecret -Force -AsPlainText

    # Install required Windows Features for Domain Controller Setup
    if ($VmRole -match '^(?=.*(?:domain|dc|ad|dns|domain-controller|ad-domain|domaincontroller|ad-domain-server|ad-dns|dc-dns))(?!.*(?:cluster|cluster-node|node)).*$') {

        Set-RequiredFirewallRules -IsActiveDirectory $true 
        
        if (-not (Test-WindowsFeatureInstalled -FeatureName "AD-Domain-Services")) {
            Install-RequiredWindowsFeatures -FeatureList @("AD-Domain-Services", "RSAT-AD-PowerShell", "DNS", "NFS-Client")
            Set-ADDomainServices -DomainName $DomainName `
                -DomainNetBiosName $DomainNetbiosName `
                -Credential $credential
        }
        else {
            Set-ADDomainServices -DomainName $DomainName `
                -DomainNetBiosName $DomainNetbiosName `
                -Credential $credential
        }
    }
    else {
        # if the length of serverList is greater than or equalt to 1 and the VM name matches with first server in the list, then it is the primary node in the cluster.
        if ($serverList.Count -ge 1 -and $serverList[0] -eq $env:computername) {

 
        }

        # Install required Windows Features for Failover Cluster and File Server Setup
        Set-RequiredFirewallRules -IsActiveDirectory $false
        Install-RequiredWindowsFeatures -FeatureList @("Failover-Clustering", "RSAT-AD-PowerShell", "FileServices", "FS-FileServer", "FS-iSCSITarget-Server", "FS-NFS-Service", "NFS-Client", "TFTP-Client", "Telnet-Client")
        Join-Domain -DomainName $DomainName `
            -DomainServerIpAddress $DomainServerIpAddress `
            -Credential $credential `
            -MaxRetries 15 `
            -RetryIntervalSeconds 30
    }
}
catch {
    Write-EventLog -Message $_.Exception.Message `
        -Source $eventSource `
        -EventLogName $eventLogName `
        -EntryType Error
}
