# A function to simplify Event Log creation and writing.
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

# Function to set the cluster shared volume (CSV)
Function Set-MscsClusterSharedVolume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $DiskFriendlyName = "Msft Virtual Disk",
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $DiskVolumeLable = "cluster-shared-volume",
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterName
    )
    try {
        # get the disk object and check if the disk is already partitioned
        $drive = Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName } 
        $isPartitioned = Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName } | Get-Partition | Select-Object -Property DiskNumber, PartitionNumber, PartitionStyle, DriveLetter

        if ($drive.PartitionStyle -eq "RAW") {
            # If now partitioned, partition the disk and format it to GPT / NTFS
            Initialize-Disk -Number $drive.DiskNumber -PartitionStyle "GPT"
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Initialize-Disk -Number $drive.DiskNumber -PartitionStyle GPT"
            # Create a new partition on the disk and assign a drive letter
            $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
            Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize"
            # Format the partition to NTFS
            Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force"
            # Add the disk to the cluster
            Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })"
        }
        else { 
            if ($null -eq $isPartitioned) {
                # If the disk is already partitioned, but not formatted, format the disk to GPT / NTFS (this mean the disk has been initialized, but not partitioned)
                $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
                Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize"
                # Format the partition to NTFS
                Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force"
                # Add the disk to the cluster
                Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })"  
            }
            else {
                # If the disk is already initialized and partitioned, format the partition to NTFS
                Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force"
                # Add the disk to the cluster
                Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
                Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })" 
            }
        }
    }
    catch {
        Write-EventLog -Message "Set-MscsClusterSharedVolume: $_.Exception.Message" -EntryType [System.Diagnostics.EventLogEntryType]::Error
        throw $_.Exception
    }
}

# Function to read parameters.json file
Function Read-ParametersJson {
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ParameterPath
    )
    # read parameters.json file and convert to object.  throw an error if the file is not found, or return the object.
    if (-not (Test-Path $ParameterPath)) { 
        throw "File not found: $ParameterPath."
        break
    }
    else {
        return (Get-Content $ParameterPath | ConvertFrom-Json)
    }
}

# populate variables from parameters.json
$parameters = Read-ParametersJson -ParameterPath "C:\\Temp\\parameters.json"
$domainName = $parameters.domainName
$domainServerIpAddress = $parameters.domainServerIpAddress
$AdminName = $parameters.AdminName
$Secret = $parameters.AdminPass
$ClusterIpAddress = $parameters.ClusterIpAddress
$ClusterName = $parameters.ClusterName
$StorageAccountName = $parameters.StorageAccountName
$StorageAccountKey = $parameters.StorageAccountKey
$ClusterNetworkName = $parameters.ClusterNetworkName
$ClusterRoleIpAddress = $parameters.ClusterRoleIpAddress
$ProbePort = $parameters.ProbePort


$expectedNodeCount = 1
$localName = $env:COMPUTERNAME
$nodes = @(Get-ADComputer -Filter { Name -like "*node*" } | Select-Object -ExpandProperty DNSHostName)

try {
    if ($nodes.Count -ge $expectedNodeCount) {
        $components = ((($nodes[0]).Split('.'))[0])

        if ($components.Equals($localName)) {
            # Get local node name and compare it to the first node in the list (cluster configuration in usually done on one node only)
            Write-EventLog -Message "Creating a new failover cluster named $ClusterName"
            New-Cluster -Name $ClusterName -Node @($nodes) -StaticAddress $ClusterIpAddress -NoStorage
            Set-ClusterQuorum -CloudWitness -AccountName $StorageAccountName -AccessKey $StorageAccountKey -Cluster $ClusterName 
            Set-MscsClusterSharedVolume -ClusterName $ClusterName
        }
    } else {
        Write-Event -Message "At least 2 or more nodes are required to form a cluster." -EntryType [System.Diagnostics.EventLogEntryType]::Error
    }
}
catch {
    Write-EventLog -Message "Error creating cluster: $_.Exception.Message" -EntryType [System.Diagnostics.EventLogEntryType]::Error
    throw $_.Exception
}