param(
    [Parameters(Mandatory=$true)] [string]$ResourceGroupName,
    [Parameters(Mandatory=$true)] [string]$ServerList,
    [Parameters(Mandatory=$true)] [string]$DomainName,
    [Parameters(Mandatory=$true)] [string]$DomainServerIpAddress,
    [Parameters(Mandatory=$true)] [string]$AdminName,
    [Parameters(Mandatory=$true)] [securestring]$AdminSecret
)

$scriptName = "Add-NodeVMsToDomain.ps1"
$scriptUrl = "https://raw.githubusercontent.com/ms-apac-csu/mscs-storage-cluster/main/extensions/$scriptName"

$command = @"
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptName
    .\Add-NodeVMsToDomain.ps1 -DomainName '$DomainName' -DomainServerIpAddress '$DomainServerIpAddress' -AdminName '$AdminName' -AdminSecret '$AdminSecret'
"@

if ($null -eq (Get-AzContext)) {
    Connect-AzAccount -UseDeviceAuthentication
}

if ($ServerList.Count -gt 0) {
    foreach($server in $ServerList) {
        $command = @"
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptName
        .\Add-NodeVMsToDomain.ps1 -DomainName '$DomainName' -DomainServerIpAddress $DomainServerIpAddress' -AdminName '$AdminName' -AdminSecret '$AdminSecret'
"@
        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName `
            -Name $server[0] `
            -CommandId 'RunPowerShellScript' `
            -Script $command
    }
}
