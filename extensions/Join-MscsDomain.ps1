param (
    [Parameter(Mandatory = $true)] [string] $DomainName,
    [Parameter(Mandatory = $true)] [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)] [string] $AdminName,
    [Parameter(Mandatory = $true)] [string] $AdminPass,
)
 
$EventSource = "CustomScriptEvent"
$EventLogName = "Application"
$MaxRetries = 30
$RetryIntervalSeconds = 1

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
}

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

  Write-EventLog -Message "Joining domain $DomainName" -Source $EventSource -EventLogName $EventLogName -EntryType Information

  $retries = 0

  # Wait for network connectivity to the domain server
  
  while ($retries -lt $MaxRetries) {
      if ( $true -ne (Test-NetConnection -ComputerName $DomainServerIpAddress -Port 389)) {
          Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress not established. Retrying in $RetryIntervalSeconds seconds." -Source $eventSource -EventLogName $eventLogName -EntryType Information
          Start-Sleep -Seconds $RetryIntervalSeconds
          $retries++
      }
      else {
          Write-EventLog -Message "Network connectivity to domain controller $DomainServerIpAddress is OK." -Source $eventSource -EventLogName $eventLogName -EntryType Information

          Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
          Clear-DnsClientCache
          
          Test-NetConnection -ComputerName 'www.google.com'
          Test-NetConnection -ComputerName $DomainName

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
