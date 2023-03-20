param (
        [Parameter(Mandatory = $true)]
        [string] $ServerList,
        [Parameter(Mandatory = $true)]
        [string] $ADDomainName
)

Write-Host [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$ServerList'))
Write-Host [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$ADDomainName'))
