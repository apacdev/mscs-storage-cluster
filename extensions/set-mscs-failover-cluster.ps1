[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $ClusterIpAddress,
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $DomainName,
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $StorageAccountName,
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $StorageAccountKey,
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $ClusterName,
    [Parameter(Mandatory = $false)] [array] [ValidateNotNullOrEmpty()] $NodeList
)

Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $Message,
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] [string] $Source = "CustomScriptEvent",
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] [string] $EventLogName = "Application",
        [Parameter(Mandatory = $false)] [System.Diagnostics.EventLogEntryType] [ValidateNotNullOrEmpty()] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    # Check whether the event source exists, and create it if it doesn't exist.
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) { [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName) }

    $log = New-Object System.Diagnostics.EventLog($EventLogName)
    $log.Source = $Source
    $log.WriteEntry($Message, $EntryType)

    # Set log directory and file
    $logDirectory = "C:\\Temp\\CseLogs"
    $logFile = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd').log"

    # Create the log directory if it does not exist
    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory | Out-Null
    }

    # Prepare log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"

    try {
        # Write log entry to the file
        Add-Content -Path $logFile -Value $logEntry
        Write-Host $logEntry
        Write-Output $logEntry
    }
    catch {
        Write-Host "Failed to write log entry to file: $($_.Exception.Message)"
        Write-Error "Failed to write log entry to file: $($_.Exception.Message)"
        thorw $_.Exception
    }
}

Function Set-MscsFailoverCluster {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterIpAddress,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $DomainName,
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $ClusterName = "mscs-cluster",
        [Parameter(Mandatory = $false)] [array] [ValidateNotNullOrEmpty()] $NodeList = @("mscswvm-node-01", "mscswvm-node-02")
    )
    $nodes = @()
    if ($null -eq ((Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue))) {
        Write-EventLog -Message "Creating a new failover cluster named $ClusterName"

        if (($NodeList.Count -eq 0) -or ($null -eq $NodeList)) {
            Write-EventLog -Message "No node list is provided. Using all nodes in the domain."
            $nodes = Get-ADComputer -Filter { Name -like "*node*" } | Select-Object -ExpandProperty DNSHostName 

        }
        else {
            foreach ($node in $NodeList) {
                $nodes += ("$($node[0]).$DomainName")
            }
        }
        try {
            Write-EventLog -Message "Creating a new failover cluster named $ClusterName"
            New-Cluster -Name $ClusterName -Node @($nodes) -StaticAddress $ClusterIpAddress -NoStorage
        }
        catch {
            Write-EventLog -Message "Failed to create a new failover cluster named $ClusterName" -EntryType [System.Diagnostics.EventLogEntryType]::Error
            Write-Error $_.Exception.Message
            throw $_.Exception
        }
    }
}
Function Set-MscsFailoverClusterQuorum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $StorageAccountName,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $StorageAccountKey,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterName
    )
    try {
        # set up a cloud witness using a storage account
        Set-ClusterQuorum -CloudWitness -AccountName csukrcconsistentstorage -AccessKey $StorageAccountKey -Cluster $ClusterName 
        Write-EventLog -Message "Set-MscsFailoverClusterQuorum: Set-ClusterQuorum -CloudWitness -AccountName csukrcconsistentstorage -AccessKey '$StorageAccountKey' -Cluster $ClusterName"
    }
    catch {
        Write-EventLog -Message "Set-MscsFailoverClusterQuorum: $_.Exception.Message" -EntryType [System.Diagnostics.EventLogEntryType]::Error
        throw $_.Exception
    }
}

Function Set-MscsClusterSharedVolume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $DiskFriendlyName = "Msft Virtual Disk",
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $DiskVolumeLable = "cluster-shared-volume",
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterName
    )
    try {
        $drive = Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName } 
        $isPartitioned = Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName } | Get-Partition | Select-Object -Property DiskNumber, PartitionNumber, PartitionStyle, DriveLetter

        if ($drive.PartitionStyle -eq "RAW") {
            Initialize-Disk -Number $drive.DiskNumber -PartitionStyle "GPT"
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Initialize-Disk -Number $drive.DiskNumber -PartitionStyle GPT"

            $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
            Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize"

            Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force"
                
            Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })"
        }
        else { 
            if ($null -eq $isPartitioned) {
                $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
                Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize"

                Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force"
                
                Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })"  
            }
            else {
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Disk $DiskFriendlyName is already partitioned. Skipping partitioning."
            }
           
        }
    }
    catch {
        Write-EventLog -Message "Set-MscsClusterSharedVolume: $_.Exception.Message" -EntryType [System.Diagnostics.EventLogEntryType]::Error
        throw $_.Exception
    }
}

try {
    Set-MscsFailoverCluster -ClusterName $ClusterName -ClusterIpAddress $ClusterIpAddress -DomainName $DomainName
    Set-MscsFailoverClusterQuorum -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ClusterName $ClusterName
    Set-MscsClusterSharedVolume -ClusterName $ClusterName -DiskFriendlyName "Msft Virtual Disk"
}
catch {
    throw $_.Exception
}
