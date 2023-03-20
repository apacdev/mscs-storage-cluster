param (
        [Parameter(Mandatory = $true)]
        [string] $ServerList,
        [Parameter(Mandatory = $true)]
        [string] $ADDomainName
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

$list = Write-Host [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$ServerList'))
$name = Write-Host [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$ADDomainName'))

Write-Output $name
Write-EventLog -Message $name -Source $EventSource -EventLogName $EventLogName -EntryType Information

