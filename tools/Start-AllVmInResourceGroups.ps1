Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -like "*mscs*" -or $_.ResourceGroupName -like "*aks*" } | ForEach-Object {
    $resourceGroupName = $_.ResourceGroupName
    Write-Host "Starting VMs in $resourceGroupName"
    Get-AzVM -ResourceGroupName $resourceGroupName | ForEach-Object {
        $vmname = $_.Name
        Write-Host "Starting $vmname"
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vmname -AsJob
    }
}

Get-Job | Wait-Job