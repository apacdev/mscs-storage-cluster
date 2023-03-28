param(
  [Parameter(Mandatory=$true)]
  [string] $DomainName,
  [Parameter(Mandatory=$true)]
  [string] $AdminName,
  [Parameter(Mandatory=$true)]
  [string] $Secret
)

$Credential = New-Object System.Management.Automation.PSCredential($AdminName, (ConvertTo-SecureString -String $Secret -AsPlainText -Force))

Add-Computer -ComputerName $env:COMPUTERNAME `
    -LocalCredential $Credential `
    -DomainName $DomainName `
    -Credential $Credential `
    -Force
