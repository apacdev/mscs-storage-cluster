param (
        [Parameter(Mandatory = $true)]
        [string] $ServerList,
        [Parameter(Mandatory = $true)]
        [string] $DomainNameToJoin
)

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


$EventSource = "CustomScriptEvent"
$EventLogName = "Application"

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
}

Write-Output $ServerList
Write-EventLog -Message $DomainNameToJoin -Source $EventSource -EventLogName $EventLogName -EntryType Information

