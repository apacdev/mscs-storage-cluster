Function Remove-MscsResourceGroups {
    if ($null -eq (Get-AzContext)) {
        Connect-AzAccount
    }
        # Get all resource groups
        Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -like "mscs_*" -or $_.ResourceGroupName -like "Default*" -or $_.ResourceGroupName -like "Network*"} | ForEach-Object {
        Remove-AzResourceGroup -Name $($_.ResourceGroupName) -AsJob -Force
    }
  Get-Job | Wait-Job
}

Remove-MscsResourceGroups