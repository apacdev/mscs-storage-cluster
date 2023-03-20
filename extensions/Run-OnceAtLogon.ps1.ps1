<#
.DISCLAIMER
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.LICENSE
Copyright (c) Microsoft Corporation. All rights reserved.

.AUTHOR
patrick.shim@live.co.kr (Patrick Shim)

.VERSION
1.0.0.0

.SYNOPSIS
This is a remote script saved in Github invoked by Azure CustomScriptExtension. This script will join the VMs to the domain.

.DESCRIPTION
This script will join the VMs to the domain.

.PARAMETER ServerList
A hashtable that contains the VM names and IP addresses. The key is the VM name, and the value is the IP address.

.PARAMETER DomainName
The name of the domain to join.

.PARAMETER DomainServerIpAddress
The IP address of the domain controller.

.PARAMETER Credential
The credential of the domain administrator.

.EXAMPLE
.\Run-OnceAtLogon.ps1.ps1 -ServerList $vmIpMap -DomainName "contoso.com" -DomainServerIpAddress "domain.contoso.com" -Credential $credential

.COMPONENT
Azure CustomScriptExtension

.OUTPUTS
None
#>

param (
    [Parameter(Mandatory = $false)]
    [array] $ServerList  = @(@("mscswvm-01", "172.16.0.100"), @("mscswvm-02", "172.16.1.101"), @("mscswvm-03", "172.16.1.102")),
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
    [Parameter(Mandatory = $true)]
    [string] $DomainServerIpAddress,
    [Parameter(Mandatory = $true)]
    [pscredential] $Credential   
)

$eventSource  = "RunOnceAtLogon"
$eventLogName = "Application"

Function Write-EventLog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory = $true)]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [string] $EventLogName,

        [Parameter(Mandatory = $false)]
        [System.Diagnostics.EventLogEntryType] $EntryType = [System.Diagnostics.EventLogEntryType]::Information
    )
    
    $log = New-Object System.Diagnostics.EventLog($EventLogName)
    $log.Source = $Source
    $log.WriteEntry($Message, $EntryType)
}

# Check whether the event source exists, and create it if it doesn't exist.
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $eventLogName)
}

#Loop through the IP addresses of the VMs in the vmIpMap hashtable, and use the IP address to create remote sessions
foreach ($vm in $ServerList) {
    Write-EventLog -Message "Joining $vm[1] ($vm[0]) to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
    try {
        $Session = New-PSSession -ComputerName $vm[1] -Credential $Credential
        Write-EventLog -Message "Successfully created remote session to $vm[1] ($vm[0])" -Source $eventSource -EventLogName $eventLogName -EntryType Information
        try {
            Write-EventLog -Message "Invoking Add-Computer to join $vm[1] ($vm[0]) to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
            Invoke-Command -Session $Session -ScriptBlock {
                param ([Parameter(Mandatory = $true)] [string] $DomainName, [Parameter(Mandatory = $true)] [pscredential] $Credential)
                Write-EventLog -Message "Altering DNS settings for $vm[1] ($vm[0])" -Source $eventSource -EventLogName $eventLogName -EntryType Information
                Set-DnsClientServerAddress -InterfaceIndex ((Get-NetAdapter -Name "Ethernet").ifIndex) -ServerAddresses $DomainServerIpAddress
                Write-EventLog -Message "Joining $vm[1] ($vm[0]) to $DomainName"
                Add-Computer -DomainName $DomainName -Credential $Credential -Restart -Force
                Write-Debug -Message "Successfully joined $vm[1] ($vm[0]) to $DomainName"
            } -ArgumentList $DomainName, $DomainServerIpAddress, $Credential
            Write-EventLog -Message "Successfully joined $vm[1] ($vm[0]) to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
        }
        catch {
            Write-EventLog -Message "Failed to join $vm[1] ($vm[0]) to $DomainName" -Source $eventSource -EventLogName $eventLogName -EntryType Information
        }
    }
    catch {
        Write-EventLog -Message "Failed to create remote session to $vm[1] ($vm[0])" -Source $eventSource -EventLogName $eventLogName -EntryType Information
    }
    finally {
        if ($Session) { 
            Remove-PSSession $Session
            Write-Debug -Message "Successfully removed remote session to $vm[1] ($vm[0])"
        }
    }
}