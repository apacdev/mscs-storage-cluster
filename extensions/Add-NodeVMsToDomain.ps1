param(
    [Parameter(Mandatory=$true)] [string] $DomainName,
    [Parameter(Mandatory=$true)] [string] $DomainServerIpAddress,
    [Parameter(Mandatory=$true)] [string] $AdminUserName,
    [Parameter(Mandatory=$true)] [securestring] $AdminSecret
)

Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) `
    -ServerAddresses $DomainServerIpAddress

Add-Computer -DomainName $DomainName `
    -Credential (New-Object System.Management.Automation.PSCredential($AdminUser, $AdminSecret)) `
    -Restart `
    -Force
    
Write-Host "hello world"
