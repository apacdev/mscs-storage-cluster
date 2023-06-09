param (
    [Parameter(Mandatory = $true)] [string] $Variables
)

# Function to download a file from a URL, retrying if necessary.
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
            Write-EventLog -Message "Failed to download file from $SourceUrl. Retrying in $RetryIntervalSeconds seconds. Retry count: $retryCount" -EntryType Warning
            Start-Sleep -Seconds (2 * $retryCount)
        }
    }

    if (-not $completed) { 
        Write-EventLog -Message "Failed to download file from $SourceUrl" -EntryType Error
        throw "Failed to download file from $SourceUrl"
    } 

    else {
        Write-EventLog -Message "Download of $SourceUrl completed successfully" -EntryType Information
    }
}

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
        Write-Output "Failed to write log entry to file: $($_.Exception.Message)"
    }
}

# Parse the VM parameters JSON.
# $Variables = '{"vm_role":"cluster", "admin_name":"pashim", "admin_password":"Roman@2013!2015", "domain_name":"neostation.org", "domain_netbios_name":"NEOSTATION", "domain_server_ip":"172.16.0.100", "cluster_name":"mscs-cluster", "cluster_ip":"172.16.1.50", "cluster_role_ip": "172.16.1.100", "cluster_network_name": "Cluster Network 1", "cluster_probe_port": "61800", "sa_name": "mscskrcommonstoragespace", "sa_key": "8AOz8Rjj2n4/aao2KdMf5YDpIzB6wfBrAZf4KpQzoEU/33EZ7GGgHlvxpCFBOTl2wMWDRxNe6bm++AStFbGMIw=="}'
# $Variables is a base64 encoded string containing a Json object.  Decode it first, then validate if it is a proper Json object. Finally, load each properties into variables.
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Variables))
$values = ConvertFrom-Json -InputObject $decoded

# Extract the VM parameters for this script to run
$AdminName = $values.admin_name
$Secret = $values.admin_password
$DomainName = $values.domain_name
$DomainServerIpAddress = $values.domain_server_ip

#######################################################################################################
# Join the VM to the domain
##############################################################################################################

$maxRetries = 30
$retryIntervalSeconds = 1
$tragetDnsFqdn = "www.google.com"
$credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $Secret -AsPlainText -Force))

Write-EventLog -Message "Joining domain $DomainName..." -EntryType Information
# Wait for network connectivity to the domain server

$retries = 0

while ($retries -lt $maxRetries) {
    if ( $true -ne (Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
        Write-EventLog -Message "Network connection to domain controller $DomainServerIpAddress cannot be reached. Retrying in $retryIntervalSeconds seconds." -EntryType Information
        Start-Sleep -Seconds $retryIntervalSeconds
        $retries++
    }
    else {
        # Carry out basic network connectivity tests with retries to ensure that the network is ready
        Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
        Clear-DnsClientCache
        
        Test-NetConnection -ComputerName $tragetDnsFqdn
        Write-EventLog -Message "Network connectivity to $tragetDnsFqdn is OK."

        Test-NetConnection -ComputerName $DomainName
        Write-EventLog -Message "Network connectivity to domain controller by FQDN ($DomainName) is OK." -EntryType Information
        
        # download and store the post-config script for the scheduled task to run after joining the domain reboot
        $scriptUrl = "https://raw.githubusercontent.com/apacdev/mscs-storage-cluster/main/extensions/set-mscs-failover-cluster.ps1"
        $scriptPath = "C:\\Temp\\set-mscs-failover-cluster.ps1"
        $parameterPath = "C:\\Temp\\variables.txt"
        $Variables | Out-File -FilePath $parameterPath -Encoding utf8 -Force

        Get-WebResourcesWithRetries -SourceUrl $scriptUrl -DestinationPath $scriptPath -MaxRetries 10 -RetryIntervalSeconds 1
        Write-EventLog -Message "Downloaded script to run after reboot (task schedule) $scriptPath" -EntryType Information

        # Register a task to run once after reboot
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"& '$scriptPath'`" -Variables '$parameterPath'"
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $trigger.EndBoundary = (Get-Date).ToUniversalTime().AddMinutes(30).ToString("o")
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -MultipleInstances IgnoreNew
        
        Register-ScheduledTask -TaskName "Configure FS Cluster" -Action $action -Trigger $trigger -Settings $settings -User $AdminName -RunLevel Highest -Force
        Write-EventLog -Message "Registered task to run after reboot (task schedule) $scriptPath" -EntryType Information
        
        # Join domain
        Write-EventLog -Message "Joining domain $DomainName" -EntryType Information

        try {
            Add-Computer -ComputerName $env:COMPUTERNAME `
                -LocalCredential $credential `
                -DomainName $DomainName `
                -Credential $credential `
                -Restart `
                -Force

            Write-EventLog -Message "Joined domain $DomainName. Now restarting the computer." -EntryType Information
            break
        }
        catch {
            Write-EventLog -Message "Failed to join domain $DomainName. Retrying in $retryIntervalSeconds seconds." -EntryType Error
            Start-Sleep -Seconds $retryIntervalSeconds
            $retries++
        }
    }
}