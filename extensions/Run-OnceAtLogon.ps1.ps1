param (
    [Parameter(Mandatory = $true)]
    [hashtable] $ServerList,
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
    [Parameter(Mandatory = $true)]
    [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)]
    [pscredential] $Credential   
)

$eventSource  = "RunOnceAtLogon"
$eventLogName = "Application"

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

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $eventLogName)
}

#Loop through the IP addresses of the VMs in the vmIpMap hashtable, and use the IP address to create remote sessions
foreach ($vm in $ServerList) {
    try {
        $Session = New-PSSession -ComputerName $vm.Value -Credential $Credential
        try {
            Invoke-Command -Session $Session -ScriptBlock {
                param ([Parameter(Mandatory = $true)] [string] $DomainName, [Parameter(Mandatory = $true)] [pscredential] $Credential)
                Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
                Add-Computer -DomainName $DomainName -Credential $Credential -Restart -Force
            } -ArgumentList $DomainName, $DomainServerIpAddress, $Credential
            Write-EventLog -Message "Successfully joined $vm to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
        }
        catch {
            Write-EventLog -Message "Failed to join $vm to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
        }
    }
    catch {
        Write-EventLog -Message "Failed to create remote session to $vm" -Source $eventSource -EventLogName $eventLogName -EntryType Information
    }
    finally {
        if ($Session) { 
            Remove-PSSession $Session
        }
    }
}