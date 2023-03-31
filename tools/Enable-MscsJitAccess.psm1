Function Enable-MscsJitNetworkAccess {
    [CmdletBinding()]
    param ( 
        [string] $ResourceGroupName,
        [string] $sourceIp = "*"
    )
    # Get all VMs in a resource group
    $policies = @()
    $policy = @()

    try {
        $resourceGroupName = (Get-AzResourceGroup -Name $ResourceGroupName).ResourceGroupName
        $location = (Get-AzResourceGroup -Name $ResourceGroupName).Location
        $subscriptionId = (get-azcontext).Subscription.Id

        Get-AzVM -ResourceGroupName $ResourceGroupName | ForEach-Object {   
            $policy = @{
                id    = "/subscriptions/$subscriptionId/resourceGroups/$($_.ResourceGroupName)/providers/Microsoft.Compute/virtualMachines/$($_.Name)"; 
                ports = @(
                    @{
                        Protocol                   = "TCP";
                        number                     = 3389;
                        allowedSourceAddressPrefix = $sourceIp;
                        maxRequestAccessDuration   = "P1D"
                    }
                ) 
            }
            $policies += $policy
        }
        Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $location -ResourceGroupName $resourceGroupName -Name "default" -VirtualMachine @($policies) -Confirm:$false
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

Function Request-MscsJitNetworkAccess {
    param (
        [string] $ResourceGroupName,
        [string] $sourceIp = "*"
    )
    $resourceGroupName = (Get-AzResourceGroup -Name $ResourceGroupName).ResourceGroupName
    $location = (Get-AzResourceGroup -Name $ResourceGroupName).Location

    $requests = @()
    Get-AzVM -ResourceGroup $ResourceGroupName | Select-Object -Property ResourceGroupName, Name, Location, Id | ForEach-Object {
        $request = @{
            id    = $_.id; 
            ports = (@{
                    number                     = 3389
                    endTimeUtc                 = Get-Date(Get-Date -AsUTC).AddHours(24) -Format O
                    allowedSourceAddressPrefix = $sourceIp
                }
            )
        }
        $requests += $request
    }
    Start-AzJitNetworkAccessPolicy -ResourceGroupName $resourceGroupName -Name "default" -VirtualMachine $requests -Location $location -Confirm:$false
}


if ($null -eq (Get-AzContext)) { 
    Connect-AzAccount
}

$ResourceGroup = "mscs_compute_resources"
Enable-MscsJitNetworkAccess -ResourceGroupName $ResourceGroup 
Request-MscsJitNetworkAccess -ResourceGroup $ResourceGroup
