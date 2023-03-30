param (
    [Parameter(Mandatory = $true)] [string] $DomainName,
    [Parameter(Mandatory = $true)] [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)] [string] $AdminName,
    [Parameter(Mandatory = $true)] [string] $AdminPass
)

# Function to simplify the creation of an event log entry.
Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $Message,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] [string] $Source,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] [string] $EventLogName,
        [Parameter(Mandatory = $false)] [System.Diagnostics.EventLogEntryType] [ValidateNotNullOrEmpty()] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    # Set event source and log name
    $EventSource = "CustomScriptEvent"
    $EventLogName = "Application"

    # Check whether the event source exists, and create it if it doesn't exist.
    if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) { [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName) }

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

Write-EventLog -Message "Joining domain $DomainName..." -Source $EventSource -EventLogName $EventLogName -EntryType Information
# Wait for network connectivity to the domain server

$retries = 0

while ($retries -lt $MaxRetries) {
    if ( $true -ne (Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
        Write-EventLog -Message "Network connection to domain controller $DomainServerIpAddress cannot be reached. Retrying in $RetryIntervalSeconds seconds." -Source $EventSource -EventLogName $EventLogName -EntryType Information
        Start-Sleep -Seconds $RetryIntervalSeconds
        $retries++
    }
    else {
        Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
        Clear-DnsClientCache
        
        Test-NetConnection -ComputerName $TargetDns
        Write-EventLog -Message "Network connectivity to $TargetDns is OK."

        Test-NetConnection -ComputerName $DomainName
        Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress is OK." -Source $EventSource -EventLogName $EventLogName -EntryType Information
        
        # Join domain
        Write-EventLog -Message "Joining domain $DomainName" -Source $EventSource -EventLogName $EventLogName -EntryType Information
        try {
            Add-Computer -ComputerName $env:COMPUTERNAME `
                -LocalCredential $Credential `
                -DomainName $DomainName `
                -Credential $Credential `
                -Restart `
                -Force

            Write-EventLog -Message "Joined domain $DomainName. Now restarting the computer." -Source $EventSource -EventLogName $EventLogName -EntryType Information
            break
        }
        catch {
            Write-EventLog -Message "Failed to join domain $DomainName. Retrying in $RetryIntervalSeconds seconds." -Source $EventSource -EventLogName $EventLogName -EntryType Error
            Start-Sleep -Seconds $RetryIntervalSeconds
            $retries++
        }
    }
}
