param(
  [Parameter(Mandatory=$true)]
  [string] $DomainName,
  [Parameter(Mandatory=$true)]
  [pscredential] $Credential
)

Add-Computer -ComputerName $env:COMPUTERNAME `
    -LocalCredential $Credential `
    -DomainName $DomainName `
    -Credential $Credential `
    -Restart `
    -Force
Start-Sleep -Second 120
Write-Host "Joined the Domain '$DomainName'."
