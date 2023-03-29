[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $ClusterIpAddress,
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $DomainName,
    [Parameter(Mandatory = $false)] [array] [ValidateNotNullOrEmpty()] $NodeList,
    [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterName = "mscs-cluster",
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $StorageAccountName = "mscskrcommonstoragespace",
    [Parameter(Mandatory = $true)]  [string] [ValidateNotNullOrEmpty()] $StorageAccountKey = "BD5ePqIHLZ4yuu57TjocxCH4JCW6LlPY36PpDpdl+JZI8tUPwI4M/r0Afmc13tHkzrivtMvpS9a3+AStT7qcMg=="
)

Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $Message,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] [string] $Source,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] [string] $EventLogName,
        [Parameter(Mandatory = $false)] [System.Diagnostics.EventLogEntryType] [ValidateNotNullOrEmpty()] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
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

    # Write log entry to the file
    Add-Content -Path $logFile -Value $logEntry
}

$EventSource = "CustomScriptEvent"
$EventLogName = "Application"

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
}

Function Set-MscsFailoverCluster {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string] [ValidateNotNullOrEmpty()] $ClusterName = "mscs-cluster",
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $ClusterIpAddress,
        [Parameter(Mandatory = $true)] [string] [ValidateNotNullOrEmpty()] $DomainName,
        [Parameter(Mandatory = $false)] [array] [ValidateNotNullOrEmpty()] $NodeList = @("mscswvm-node-01", "mscswvm-node-02")
    )
    $nodes = @()
    if ($null -eq ((Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue))) {
        Write-EventLog -Message "Creating a new failover cluster named $ClusterName" -Source $EventSource -EventLogName $EventLogName

        if (($NodeList.Count -eq 0) -or ($null -eq $NodeList)) {
            Write-EventLog -Message "No node list is provided. Using all nodes in the domain." -Source $EventSource -EventLogName $EventLogName
            $nodes = Get-ADComputer -Filter { Name -like "*node*" } | Select-Object -ExpandProperty DNSHostName 

        }
        else {
            foreach ($node in $NodeList) {
                $nodes += ("$($node[0]).$DomainName")
            }
        }
        try {
            Write-EventLog -Message "Creating a new failover cluster named $ClusterName" -Source $EventSource -EventLogName $EventLogName
            New-Cluster -Name $ClusterName -Node $nodes -StaticAddress $ClusterIpAddress -NoStorage
        }
        catch {
            Write-EventLog -Message "Failed to create a new failover cluster named $ClusterName" -Source $EventSource -EventLogName $EventLogName -EntryType [System.Diagnostics.EventLogEntryType]::Error
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
        Set-ClusterQuorum -CloudWitness -AccountName $StorageAccountName -AccessKey $StorageAccountKey -Cluster $ClusterName
        Write-EventLog -Message "Set-MscsFailoverClusterQuorum: Set-ClusterQuorum -CloudWitness -AccountName $StorageAccountName -AccessKey $StorageAccountKey -Cluster $ClusterName" -Source $EventSource -EventLogName $EventLogName
    }
    catch {
        Write-Error $_.Exception.Message
        Write-EventLog -Message "Set-MscsFailoverClusterQuorum: $_.Exception.Message" -Source $EventSource -EventLogName $EventLogName -EntryType [System.Diagnostics.EventLogEntryType]::Error
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

        if ($drive.PartitionStyle -eq "RAW")
        {
            Initialize-Disk -Number $drive.DiskNumber -PartitionStyle "GPT"
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Initialize-Disk -Number $drive.DiskNumber -PartitionStyle GPT" -Source $EventSource -EventLogName $EventLogName

            $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
            Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize" -Source $EventSource -EventLogName $EventLogName

            Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force" -Source $EventSource -EventLogName $EventLogName
                
            Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })" -Source $EventSource -EventLogName $EventLogName
        } else { 
            if ($null -eq $isPartitioned) {
                $part = New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize 
            Write-EventLog -Message "Set-MscsClusterSharedVolume: New-Partition -DiskNumber $drive.DiskNumber -AssignDriveLetter -UseMaximumSize" -Source $EventSource -EventLogName $EventLogName

            Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Format-Volume -DriveLetter $part.DriveLetter -FileSystem NTFS -NewFileSystemLabel $DiskVolumeLable -Confirm:$false -Force" -Source $EventSource -EventLogName $EventLogName
                
            Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })
            Write-EventLog -Message "Set-MscsClusterSharedVolume: Add-ClusterDisk -Cluster $ClusterName -InputObject (Get-Disk | Where-Object { $_.FriendlyName -eq $DiskFriendlyName })" -Source $EventSource -EventLogName $EventLogName  
        
            } else {
            # delete the existing partner
            }
                        
            }
    }
    catch {
        Write-EventLog -Message "Set-MscsClusterSharedVolume: $_.Exception.Message" -Source $EventSource -EventLogName $EventLogName -EntryType [System.Diagnostics.EventLogEntryType]::Error
        Write-Error $_.Exception.Message
        throw $_.Exception
    }
}

try {
    Set-MscsFailoverCluster -ClusterName $ClusterName -ClusterIpAddress $ClusterIpAddress -DomainName $DomainName
    Set-MscsFailoverClusterQuorum -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ClusterName $ClusterName
    Set-MscsClusterSharedVolume -ClusterName $ClusterName -DiskFriendlyName "Msft Virtual Disk"
}
catch {
    Write-Error $_.Exception.Message
    throw $_.Exception
}
