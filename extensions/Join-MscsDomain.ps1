param(
  [Parameter(Mandatory=$true)]
  [string] $DomainName,
  [Parameter(Mandatory=$true)]
  [string] $AdminName,
  [Parameter(Mandatory=$true)]
  [ps] $Secret
)

$Credential = New-Object System.Management.Automation.PSCredential($AdminName, $Secret)

$eventSource = "CustomScriptEvent"
$eventLogName = "Application"

if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) { [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $eventLogName) }

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

    # Set log directory and file
    $logDirectory = "C:\temp\cselogs"
    $logFile = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd').log"

    # Create the log directory if it does not exist
    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory | Out-Null
    }

    # Prepare log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    # Write log entry to the file
    Add-Content -Path $logFile -Value $logEntry
}

Function Join-Domain {
        [Parameter()] [int] $MaxRetries = 10,
        [Parameter()] [int] $RetryIntervalSeconds = 5
    )
                
    $retries = 0
    
    # Wait for network connectivity to the domain server
    while ($retries -lt $MaxRetries) {
        if ( $true -ne (Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
            Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress not established. Retrying in $RetryIntervalSeconds seconds." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            Start-Sleep -Seconds $RetryIntervalSeconds
            $retries++
        }
        else {
            Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress established." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            Write-EventLog -Message "Flushing DNS before setting the client DNS to the domain controller" -Source $eventSource -EventLogName $eventLogName -EntryType Information        
            Clear-DnsClientCache

            # Set DNS server to the domain controller
            Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
            Clear-DnsClientCache

            Write-EventLog -Message "Set DNS server on this server to $DomainServerIpAddress" -Source $eventSource -EventLogName $eventLogName -EntryType Information
            Write-EventLog -Message "Sleeping for some minutes..." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            
            Start-Sleep -Seconds 30
            Write-EventLog -Message "Woke up to join the domain..." -Source $eventSource -EventLogName $eventLogName -EntryType Information
            
            # Join domain
            Write-EventLog -Message "Joining domain $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
            try {
                Add-Computer -ComputerName $env:COMPUTERNAME `
                    -LocalCredential $Credential `
                    -DomainName $DomainName `
                    -Credential $Credential `
                    -Force
                    
                Write-EventLog -Message "Joined domain $DomainName. Now restarting the computer." -Source $eventSource -EventLogName $eventLogName -EntryType Information
                break
            }
            catch {
                Write-EventLog -Message "Failed to join domain $DomainName. Retrying in $RetryIntervalSeconds seconds." -Source $eventSource -EventLogName $eventLogName -EntryType Information
                Start-Sleep -Seconds $RetryIntervalSeconds
                $retries++
            }
        }
    }
}


