param (
    [Parameter(Mandatory = $true)] [string] $DomainName,
    [Parameter(Mandatory = $true)] [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)] [string] $AdminName,
    [Parameter(Mandatory = $true)] [string] $AdminPass,
    [Parameter(Mandatory = $true)] [string] $ClusterIpAddress,              # Cluster's IP
    [Parameter(Mandatory = $true)] [string] $ClusterName,                   # MSCS Cluster Instance Name
    [Parameter(Mandatory = $true)] [string] $StorageAccountName,            # Cloud Witness Storage Account Name
    [Parameter(Mandatory = $true)] [string] $StorageAccountKey,             # Cloud Witness Storage Account Key
    [Parameter(Mandatory = $true)] [string] $ClusterNetworkName,            # Cluster Network 1
    [Parameter(Mandatory = $true)] [string] $ClusterRoleIpAddress,          # File Server IP (ILB)
    [Parameter(Mandatory = $true)] [string] $ProbePort                      # Probe Port (ILB)
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
        Write-Error "Failed to write log entry to file: $($_.Exception.Message)"
        thorw $_.Exception
    }
}

$MaxRetries = 30
$RetryIntervalSeconds = 1
$TargetDns = "www.google.com"
$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $AdminPass -AsPlainText -Force))

Write-EventLog -Message "Joining domain $DomainName..." -EntryType Information
# Wait for network connectivity to the domain server

$retries = 0

while ($retries -lt $MaxRetries) {
    if ( $true -ne (Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
        Write-EventLog -Message "Network connection to domain controller $DomainServerIpAddress cannot be reached. Retrying in $RetryIntervalSeconds seconds." -EntryType Information
        Start-Sleep -Seconds $RetryIntervalSeconds
        $retries++
    }
    else {
        Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
        Clear-DnsClientCache
        
        Test-NetConnection -ComputerName $TargetDns
        Write-EventLog -Message "Network connectivity to $TargetDns is OK."

        Test-NetConnection -ComputerName $DomainName
        Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress is OK." -EntryType Information
        
        try {
            $scriptUrl = "https://raw.githubusercontent.com/ms-apac-csu/mscs-storage-cluster/main/extensions/set-mscs-failover-cluster.ps1"
            $scriptPath = "C:\\Temp\\set-mscs-failover-cluster.ps1"
            # Save parameters for post-configuration process after domain join and reboot
            $parameterPath = "C:\\Temp\\parameters.json"
            $parameters = @{
                "DomainName" = $DomainName
                "ClusterName" = $ClusterName
                "ClusterIpAddress" = $ClusterIpAddress
                "StorageAccountName" = $StorageAccountName
                "StorageAccountKey" = $StorageAccountKey
                "ClusterNetworkName" = $ClusterNetworkName
                "ClusterRoleIpAddress" = $ClusterRoleIpAddress
                "ProbePort" = $ProbePort
            } | ConvertTo-Json | Out-File -FilePath $parameterPath -Encoding ASCII
            Write-EventLog -Message "Saved parameters for post-configuration process after domain join and reboot $parameters" -EntryType Information

            # Download script to run after reboot
            Get-WebResourcesWithRetries -SourceUrl $scriptUrl -DestinationPath $scriptPath -MaxRetries 10 -RetryIntervalSeconds 1
            Write-EventLog -Message "Downloaded script to run after reboot (task schedule) $scriptPath" -EntryType Information

            # Register a task to run once after reboot
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"& '$scriptPath'`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $trigger.EndBoundary = (Get-Date).ToUniversalTime().AddMinutes(120).ToString("o")
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8 -MultipleInstances IgnoreNew
            Register-ScheduledTask -TaskName "Configure FS Cluster" -Action $action -Trigger $trigger -Settings $settings -User $AdminName -RunLevel Highest -Force
            Write-EventLog -Message "Registered task to run after reboot (task schedule) $scriptPath" -EntryType Information

        } catch {
            Write-EventLog -Message "Failed to download script to join machines to domain $scriptPath" -EntryType Error
        }
        
        # Join domain
        Write-EventLog -Message "Joining domain $DomainName" -EntryType Information
        try {
            Add-Computer -ComputerName $env:COMPUTERNAME `
                -LocalCredential $Credential `
                -DomainName $DomainName `
                -Credential $Credential `
                -Restart `
                -Force

            Write-EventLog -Message "Joined domain $DomainName. Now restarting the computer." -EntryType Information
            break
        }
        catch {
            Write-EventLog -Message "Failed to join domain $DomainName. Retrying in $RetryIntervalSeconds seconds." -EntryType Error
            Start-Sleep -Seconds $RetryIntervalSeconds
            $retries++
        }
    }
}