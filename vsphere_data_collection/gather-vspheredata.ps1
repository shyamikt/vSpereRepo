#Global Variables


$oversubscriptionfactor = 3.0
$sessiontimeout = 1800
$summaryfilename = "summary.txt"
$minimumvhardwareversion = "15"
$hostmaxmemoryusagepercent = "80"



function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Info','Warning','Error')]
        [string]$Severity = 'Info',

        [Parameter()]
        [switch]$noconsole = $false
    )
    if(!$noconsole)
    {
        Write-Host "$(Get-Date -f s) - $message"
    }
    Add-Content -Path "$pwd\log.txt" -Value "$(Get-Date -f s) $severity $message"
}

$initialTimeout = (Get-PowerCLIConfiguration -Scope Session).WebOperationTimeoutSeconds
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $sessiontimeout -Confirm:$false | Out-Null

# Write-Log -Message 'Foo was $true' -Severity Information
# Write-Log -Message 'Foo was $false' -Severity Error

$vcenter = Read-Host -Prompt "Enter vCenter Address"
$credential = Get-Credential -Message "Enter credentials for vCenter $vcenter"
$summaryfile = "$($pwd)\$vcenter-$summaryfilename.txt"
try{
    Write-log -Message "Connecting to vCenter $vcenter" -Severity Info
    Connect-viserver -Server $vcenter -Credential $credential | Out-Null
}
Catch{
    write-log -Message "Error connecting to vCenter $vcenter. Check your address and credentials then try again. `n$($error)" -Severity Error
    exit
}

# Additional Items
# - Write VM's that are out of date from the host hardware version
# - Find hosts that are an older version than the rest of the cluster
# - Find VM's with limits
# - Find hosts where memory usage > 80% or some predefind threshold
# - Find VM's with CPU or Memory Reservation

write-log -Message "***NEW REPORT***" -Severity INFO -noconsole
write-log -Message "Writing summary to $($summaryfile)..." -Severity Info
Add-Content -Path $summaryfile -Value "Report Date: $(Get-Date -f s)"

write-log -Message "Gathering Cluster Info..." -Severity Info
$clusterinfo = Get-Cluster

write-log -Message "Gathering Host Info..." -Severity Info
$hostinfo = $clusterinfo | Get-VMHost

write-log -Message "Gathering VM Info..." -Severity Info
$virtualmachines = $clusterinfo | Get-VM | Where-Object {$_.ExtensionData.Config.ManagedBy.extensionKey -NotLike "com.vmware.vcDr*"}

#region Snapshot Data
write-log -Message "Gathering Snapshot Data..." -Severity Info
$vmsnapdata = $virtualmachines | Get-Snapshot | Select-object VM, Created, @{N="SizeGB";E={[math]::Round($_.SizeGB,2)}}
Add-Content -Path $summaryfile -Value "Virtual Machines with Snapshots: `t $(($vmsnapdata | Select-Object -Unique VM | Measure-Object VM).Count)"
Add-Content -Path $summaryfile -Value "Oldest Snapshot: `t`t`t $(($vmsnapdata | Sort-Object -Property Created | Select-Object -First 1).Created.ToString())"
Add-Content -Path $summaryfile -Value "VMs with >1 Snapshot `t`t`t $(($vmsnapdata | Group-Object -Property VM | Where-Object {$_.Count -gt 1} | Measure-Object).Count)"
Add-Content -Path $summaryfile -Value "Total Size of Snapshots (GB): `t`t $(($vmsnapdata | Measure-Object -Sum SizeGB).Sum)"
$vmsnapdata | Export-CSV ".\$($vcenter)-snapshotdata.csv" -notypeinfo

write-log -Message "Gathering Orphaned Snapshots..." -Severity Info
$vmsnaporphanes = $virtualmachines | Where-Object { (Get-HardDisk -vm $_ | Where-Object { $_.filename -like "*-000*.vmdk" }) -and (Get-SnapShot -VM $_ | Measure-Object).Count -lt 1 } | Select-Object Name
Add-Content -Path $summaryfile -Value "VMs with Orphaned Snaps: `t`t $(($vmsnaporphanes | Measure-Object).Count)"
$vmsnaporphanes | Export-CSV ".\$($vcenter)-orphanedsnaps.csv" -notypeinfo
#endregion

#region Powered off VMs
write-log -Message "Gathering Powered Off VM Info..." -Severity Info
$vmpoweredoffvmdata = $virtualmachines | Where-Object {$_.PowerState -eq "PoweredOff"} | Select-Object Name,@{N="DiskSpace";E={(($_ | Get-HardDisk | Select-Object CapacityGB).CapacityGB | Measure-Object -Sum).Sum }}
Add-Content -Path $summaryfile -Value "Powered Off VMs: `t`t`t $(($vmpoweredoffvmdata | Measure-Object).Count)"
Add-Content -Path $summaryfile -Value "Powered Off VM Space Usage (GB): `t $([math]::Round(($vmpoweredoffvmdata | Measure-Object -Sum DiskSpace).Sum,2))"
$vmpoweredoffvmdata | Export-CSV ".\$($vcenter)-poweredoff.csv" -notypeinfo
#endregion

#region Tools Status
write-log -Message "Gathering VMware Tools and Hardware Status..." -Severity Info
$vmtoolshwdata = $virtualmachines | Where-Object {$_.PowerState -eq "PoweredOn"}| Select-Object Name,@{N="HardwareVersion";E={($_.HardwareVersion).Split('-')[1]}},@{N="ToolStatus";E={$_.ExtensionData.Guest.ToolsStatus}}
Add-Content -Path $summaryfile -Value "Virtual Hardware < v10: `t`t $(($vmtoolshwdata | Where-Object {$_.HardwareVersion -lt 10} | Measure-Object).Count)" 
Add-Content -Path $summaryfile -Value "Virtual Tools Old: `t`t`t $(($vmtoolshwdata | Where-Object {$_.ToolStatus -eq "toolsOld"} | Measure-Object).Count)"
Add-Content -Path $summaryfile -Value "Virtual Tools Not Installed: `t`t $(($vmtoolshwdata | Where-Object {$_.ToolStatus -eq "toolsNotInstalled"} | Measure-Object).Count)"
Add-Content -Path $summaryfile -Value "Virtual Tools Not Running: `t`t $(($vmtoolshwdata | Where-Object {$_.ToolStatus -eq "toolsNotRunning"} | Measure-Object).Count)"
$vmtoolshwdata | Export-CSV ".\$($vcenter)-vmtoolshw.csv" -notypeinfo
#endregion

#region VM CD Rom State
write-log -Message "Gathering VM CD-Rom State..." -Severity Info
$vmcdromdata = $virtualmachines | Where-Object {$_.PowerState -eq "PoweredOn"} | Get-CDDrive | Where-Object {$_.ConnectionState.Connected -eq "true" } | Select-Object Parent,IsoPath,ConnectionState
Add-Content -Path $summaryfile -Value "Connected CD-Roms: `t`t`t $(($vmcdromdata | Measure-Object).Count)"
$vmcdromdata | Export-CSV ".\$($vcenter)-cdromstate.csv" -notypeinfo
#endregion

#region Host PwrMgmt
write-log -Message "Gathering Power Mgmt Status of Cluster..." -Severity Info
$clusterpwrstatedata = $hostinfo | Select-Object Name, @{N='Power Technology';E={$_.ExtensionData.Hardware.CpuPowerManagementInfo.HardwareSupport}}, @{N='Current Policy';E={$_.ExtensionData.Hardware.CpuPowerManagementInfo.CurrentPolicy}}
$clusterpwrstatedata | Export-CSV ".\$($vcenter)-clusterpwrmgmt.csv" -notypeinfo
#endregion

#region NTP Config
write-log -Message "Gathering NTP Config..." -Severity Info
$ntpdata = $hostinfo | Sort-Object Name | Select-Object Name, @{N="NTP";E={Get-VMHostNtpServer $_}}
Add-Content -Path $summaryfile -Value "# Hosts Missing NTP Config: `t`t $(($ntpdata | Where-Object {$_.NTP -eq $null } | Measure-Object).Count)"
$ntpdata | Export-CSV ".\$($vcenter)-hostntpdata.csv" -notypeinfo
#endregion

#region Cluster HA Status
write-log -Message "Gathering HA Status of Cluster..." -Severity Info
$clusterhastatusdata = $clusterinfo | Sort-Object name | Select-Object Name,HAAdmissionControlEnabled
$clusterhastatusdata | Export-CSV ".\$($vcenter)-clusterhastatus.csv" -notypeinfo
#endregion

#region Host Multipath
write-log -Message "Gathering Host Multipathing Info..." -Severity Info
$hostmultipath = $hostinfo | Get-ScsiLun -LunType disk | Select-Object VMHost,CanonicalName,MultipathPolicy,IsLocal | Where-Object { $_.MultipathPolicy -notlike "RoundRobin" -and $_.IsLocal -eq $FALSE }
Add-Content -Path $summaryfile -Value "Hosts with Fixed Path Devices: `t`t $(($hostmultipath | Select-Object -Unique VMHost | Measure-Object).Count)"
$hostmultipath | Export-CSV ".\$($vcenter)-multipath.csv" -notypeinfo
#endregion

#region VFMS Datastore Types
write-log -Message "Gathering Datastore Info..." -Severity Info
$vmfsdatastoredata = $clusterinfo | Get-Datastore | Where-OBject {$_.Type -eq "VMFS"} | Select-Object Name,CapacityMB,FreeSpaceMB,Type,@{N="VMFSVersion";E={$_.ExtensionData.Info.VMFS.MajorVersion}}
Add-Content -Path $summaryfile -Value "VMFS5 Datatsores: `t`t $(($vmfsdatastoredata | Where-Object { $_.VMFSVersion -eq "5" } | Measure-Object).Count)"
$vmfsdatastoredata | Export-CSV ".\$($vcenter)-vmfsdatastoredata.csv" -notypeinfo
#endregion

#region Legacy Network Adapters
write-log -Message "Gathering VM w/o VMXNET3..." -Severity Info
$vmlegacyadapter = $virtualmachines | Get-NetworkAdapter | Select-Object @{N='VM';E={$_.Parent.Name}},@{N='AdapterName';E={$_.Name}},@{N='Type';E={$_.Type}}
Add-Content -Path $summaryfile -Value "Count of Non-VMXNET3 VMs: `t`t $(($vmlegacyadapter | Where-Object { $_.Type -ne "VMXNET3" } | Select-Object -Unique VM | Measure-Object).Count)"
$vmlegacyadapter | Export-CSV ".\$($vcenter)-e1000vms.csv" -notypeinfo
#endregion

#region Legacy SCSI Adapters
write-log -Message "Gathering VM SCSI Adapters..." -Severity Info
$vmscsiadapters = $virtualmachines | Get-ScsiController | Select-Object Parent,Name,Type
Add-Content -Path $summaryfile -Value "Count of Non-LSI/PVSCSI VMs: `t`t $(($vmscsiadapters | Where-Object { ($_.Type -like "*VirtualLsiLogic*") -or ($_.Type -like "*VirtualBusLogic*") } | Select-Object -Unique Parent | Measure-Object).Count)"
$vmscsiadapters | Export-CSV ".\$($vcenter)-vmscsiadapters.csv" -notypeinfo
#endregion

#region Cluster Oversubscription
write-log -Message "Gathering cluster oversubscription data..." -Severity Info
$clusteroversubdata = $clusterinfo | Sort-Object name | Select-Object Name, @{N="CpuOversubscriptionFactor";E={[math]::Round((($_|get-VM| Where-Object {$_.PowerState -eq "PoweredOn"} | Measure-Object numcpu -sum).Sum)/(($_ | get-vmhost | Measure-Object numcpu -sum).sum)/1,2)}}
Add-Content -Path $summaryfile -Value "Clusters oversubscribed: `t`t $(($clusteroversubdata | Where-Object {$_.CpuOversubscriptionFactor -gt $oversubscriptionfactor} | Measure-Object).Count)"
$clusteroversubdata | Export-CSV ".\$($vcenter)-oversub.csv" -notypeinfo
#endregion


write-host "`n"

#Write-Host "% Hosts not in High Perf: `t" -NoNewline
#$clusterhastatusdata.

Get-Content -Path $summaryfile

Write-host "`nRAW Data dumped to directory: $($pwd.Path)`n"
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $initialTimeout -Confirm:$false | Out-Null

disconnect-viserver -confirm:$false