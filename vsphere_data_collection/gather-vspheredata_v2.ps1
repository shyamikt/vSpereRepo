###############################################################################
#
# This script collects information on the vSphere enviornemnt. It is meant
# to be run manually per vCenter.
#
# Configure variables below to your liking.
#
# Status: In Development
#
# Usage: .\gather-vspheredata_v2.ps1
#
# To Do:
# TODO: Show MSCS Disks
#
###############################################################################

#Global Variables

$oversubscriptionfactor = 3.0
$sessiontimeout = 1800
$summaryfilename = "summary_v2-dev.txt"
$minvmhwversion = 15
$hostmaxmemoryusagepercent = 80

# excludes SRM virtual machines from the $virtualmachines variable.
$excludeSRMvms = $true


# You can turn off each data gathering section by changing the following varibles to $false.
$gathersnapshotdata = $true # *v2
$gatherpoweredoffvmdata = $true # *v2
$gathervmtoolshwdata = $true # *v2
$gathervmcdromdata = $true # *v2
$gathervmswithreservations = $true # *v2
$gathervmswithtimesync = $true # v2
$gatherhostpwrdata = $true # *v2
$gatherhostntpdata = $true # *v2
$gatherclusterhadata = $true # *v2
$gatherhostsyslog = $false # *v2
$gatherHostADConfig = $true # v2
$gatherhostmultipathdata = $false
$gathervmfsversiondata = $true # *v2
$gatherlegacynicdata = $false
$gatherlegacyscsidata = $false
$gatherclusteroversubdata = $false




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
function Get-SnapshotSize{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$VM
    )

}
function Convert-YNtoTF{
    [CmdletBinding()]
    param(
        [ValidateSet("Y","N")]
        [string]$choice
    )
    
    if($choice -eq "Y"){
        return $true
    }
    elseif($choice -eq "N"){
        return $false
    }
}
#region Active vCenter Connection?
if(($global:defaultviserver).Count -eq 1 -and $global:defaultviserver.IsConnected -eq $true){
    write-host "The current console is already connected $($global:defaultviserver.Name)."
    $vcenter = $global:defaultviserver.Name
    Do {$choice = Read-Host -Prompt "Would you like to continue with this vCenter(Y/N)?"}
    Until (($choice -eq "Y") -or ($choice -eq "N"))
    $choice = Convert-YNtoTF -choice $choice
    if(-not $Choice){
        $continue = $false
    }
    write-host "Continuing with vCenter $($global:defaultviserver.Name)"
}
elseif(($global:defaultviserver).Count -gt 1){
    Write-host "The console is already connected to the following vCenters."
    $global:defaultviserver.name
    Do {$choice = Read-Host -Prompt "Would you like to continue (Y/N)?"}
    Until (($choice -eq "Y") -or ($choice -eq "N"))
    $choice = Convert-YNtoTF -choice $choice
    if($choice){
        $vcenter = Read-Host -Prompt "Which vCenter would you like to use (FDQN as shown)?"
        write-host "Continuing with vCenter $vcenter"
        $continue = $true
    }
    else{
        $continue = $false
    }
}
#endregion

if(-not $continue){
    #Disconnect-VIServer -confirm $false -force
    $vcenter = Read-Host -Prompt "Enter vCenter Address"
    $credential = Get-Credential -Message "Enter credentials for vCenter $vcenter"
    Write-log -Message "Connecting to vCenter $vcenter" -Severity Info
    try{
        Connect-viserver -Server $vcenter -Credential $credential
    }
    Catch{
        write-log -Message "Error connecting to vCenter $vcenter. Check your address and credentials then try again. `n$($error)" -Severity Error
        exit;
    }
}

$initialTimeout = (Get-PowerCLIConfiguration -Scope Session).WebOperationTimeoutSeconds
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $sessiontimeout -Confirm:$false | Out-Null

# Write-Log -Message 'Foo was $true' -Severity Information
# Write-Log -Message 'Foo was $false' -Severity Error


$summaryfile = "$($pwd)\$vcenter-$summaryfilename"


# Additional Items
# TODO: Write VM's that are out of date from the host hardware version
# TODO: Find hosts that are an older version than the rest of the cluster
# TODO: Find VM's with limits
# TODO: Find hosts where memory usage > 80% or some predefind threshold
# TODO: VM's that breach NUMA config
# TODO: VM's with Thin Provision Disks

write-log -Message "***NEW REPORT***" -Severity INFO -noconsole
write-log -Message "Writing summary to $($summaryfile)..." -Severity Info
Add-Content -Path $summaryfile -Value "`nReport Date: $(Get-Date -f s)"

write-log -Message "Gathering Cluster Info..." -Severity Info
$clusterinfo = Get-View -ViewType ClusterComputeResource -Server $vcenter
$clusterinfov1 = Get-Cluster -Server $vcenter
write-log -Message "$(($clusterinfo).count) clusters found."

write-log -Message "Gathering Host Info..." -Severity Info
#$hostinfo = Get-VMHost
$hostinfo = Get-View -ViewType HostSystem -Server $vcenter
$hostinfov1 = $clusterinfov1 | Get-VMHost -Server $vcenter
write-log -Message "$(($hostinfo).count) hosts found."

write-log -Message "Gathering Datastore Info..." -Severity Info
#$hostinfo = Get-VMHost
$datastoreinfo = Get-View -ViewType Datastore -Server $vcenter
write-log -Message "$(($datastoreinfo).count) datastores found."

write-log -Message "Gathering VM Info..." -Severity Info
if($excludeSRMvms){
    $virtualmachines = Get-View -ViewType Virtualmachine -Server $vcenter | Where-Object {$_.Config.ManagedBy.extensionKey -NotLike "com.vmware.vcDr*" -and $_.Config.Template -eq $False}
}
else {
    $virtualmachines = Get-View -ViewType Virtualmachine -Server $vcenter
}
write-log -Message "$(($virtualmachines).count) VMs found."

#region Snapshot Data
if($gathersnapshotdata){
    write-log -Message "Gathering Snapshot Data..." -Severity Info
    $i=1 # Sets up loop iterator
    $vmswithsnaps = $virtualmachines | Where-Object {$_.Snapshot -ne $null} # Filters VMs with Snapshots
    $count = $vmswithsnaps.count # Counts num of VMs with snaps
    $vmsnapdata=@() # Initialize array for use in loop.
    write-log -Message "$count VMs found with Snapshots..." -Severity Info
    foreach($thisvm in $vmswithsnaps){
        $thissnapdata = New-Object PSObject
        Write-Progress -Activity "Gathering Snapshot Data... $($thisvm.Name)" -PercentComplete (($i*100)/$count) -Status "$i of $count - $(([math]::Round((($i)/$count * 100),0))) %"
        # Gathers snapshot data
        $thissnapdata = Get-Snapshot -VM $thisvm.Name -ErrorAction SilentlyContinue | Select-Object VM,Name,Created, @{N="SizeGB";E={[math]::Round($_.SizeGB,2)}}
        $vmsnapdata += $thissnapdata
        $i++
    }
    Clear-Variable -Name thisvm
    Clear-Variable -Name thissnapdata  

    Add-Content -Path $summaryfile -Value "Virtual Machines with Snapshots: `t $(($vmsnapdata | Select-Object -Unique VM | Measure-Object VM).Count)"
    Add-Content -Path $summaryfile -Value "Oldest Snapshot: `t`t`t $(($vmsnapdata | Sort-Object -Property Created | Select-Object -First 1).Created.ToString())"
    Add-Content -Path $summaryfile -Value "VMs with >1 Snapshot `t`t`t $(($vmsnapdata | Group-Object -Property VM | Where-Object {$_.Count -gt 1} | Measure-Object).Count)"
    Add-Content -Path $summaryfile -Value "Total Size of Snapshots (GB): `t`t $(($vmsnapdata | Measure-Object -Sum SizeGB).Sum)"
    $vmsnapdata | Export-CSV ".\$($vcenter)-snapshotdata.csv" -notypeinfo

    write-log -Message "Gathering Orphaned Snapshots..." -Severity Info
    $vmswithoutsnaps = $virtualmachines | Where-Object {$_.Snapshot -eq $null} # Filters VMs without snapshots

    # Finds VMs with a base disk of a snap from VMs without a registered snapshot.
    $vmsnaporphanes = $vmswithoutsnaps | Select-Object @{N="VM";E={$_.Name}},@{N="DiskInfo";E={$_.Layout.Disk.DiskFile}} | Where-Object {$_.DiskInfo -like "*-000*.vmdk"} | Select-Object -Unique VM,DiskInfo

    Add-Content -Path $summaryfile -Value "VMs with Orphaned Snaps: `t`t $(($vmsnaporphanes | Measure-Object).Count)"
    $vmsnaporphanes | Export-CSV ".\$($vcenter)-orphanedsnaps.csv" -notypeinfo
    Write-Progress -Activity "Gathering Snapshot Data..." -Completed
}
#endregion

#region VMs with Reservations, v2
if($gathervmswithreservations){
   # ($virtualmachines | Select -first 1).Config.CpuAllocation & MemoryAllocation
   write-log -Message "Gathering VMs with Reservations..." -Severity Info
   $vmreservedata = $virtualmachines | Select-Object Name,@{N="CPUReservation";E={$_.ResourceConfig.CpuAllocation.Reservation}},@{N="MemReservation";E={$_.ResourceConfig.MemoryAllocation.Reservation}}
   Add-Content -Path $summaryfile -Value "Reserved VMs: `t`t`t`t $(($vmreservedata | Where-Object {$_.CPUReservation -ne '0' -OR $_.MemReservation -ne '0'}).Count)"
   $vmreservedata | Export-CSV ".\$($vcenter)-vmreservdata.csv" -notypeinfo
}
#endregion

#region Powered off VMs, v2
if($gatherpoweredoffvmdata){
    write-log -Message "Gathering Powered Off VM Info..." -Severity Info
    $vmpoweredoffvmdata = $virtualmachines | Where-Object {$_.Summary.Runtime.PowerState -eq "PoweredOff"} | Select-Object Name,@{N="DiskSpace";E={(($_.Summary.Storage.Committed)/1GB | Measure-Object -Sum).Sum}}    
    Add-Content -Path $summaryfile -Value "Powered Off VMs: `t`t`t $(($vmpoweredoffvmdata | Select-Object -Unique Name).Count)"
    Add-Content -Path $summaryfile -Value "Powered Off VM Space Usage (GB): `t $([math]::Round(($vmpoweredoffvmdata | Measure-Object -Sum DiskSpace).Sum,2))"
    $vmpoweredoffvmdata | Export-CSV ".\$($vcenter)-poweredoff.csv" -notypeinfo
}
#endregion

#region Tools Status, v2
if($gathervmtoolshwdata){
    write-log -Message "Gathering VMware Tools and Hardware Status..." -Severity Info
    $vmtoolshwdata = $virtualmachines | Select-Object Name,@{N="ToolsStatus";E={$_.Guest.ToolsStatus}},@{N="ToolsVersion";E={$_.Guest.ToolsVersion}},@{N="ToolsRunningStatus";E={$_.Guest.ToolsRunningStatus}},@{N="HWVersion";E={[Int]($_.Config.Version).Split('-')[1]}}
    #$vmtoolshwdata = $virtualmachines | Where-Object {$_.PowerState -eq "PoweredOn"}| Select-Object Name,@{N="HardwareVersion";E={($_.HardwareVersion).Split('-')[1]}},@{N="ToolStatus";E={$_.ExtensionData.Guest.ToolsStatus}}
    Add-Content -Path $summaryfile -Value "Virtual Hardware < v$($minvmhwversion): `t`t $(($vmtoolshwdata | Where-Object {$_.HardwareVersion -lt $minvmhwversion} | Measure-Object).Count)" 
    Add-Content -Path $summaryfile -Value "Virtual Tools Old: `t`t`t $(($vmtoolshwdata | Where-Object {$_.ToolsStatus -eq "toolsOld"} | Measure-Object).Count)"
    Add-Content -Path $summaryfile -Value "Virtual Tools Not Installed: `t`t $(($vmtoolshwdata | Where-Object {$_.ToolsStatus -eq "toolsNotInstalled"} | Measure-Object).Count)"
    Add-Content -Path $summaryfile -Value "Virtual Tools Not Running: `t`t $(($vmtoolshwdata | Where-Object {$_.ToolsStatus -eq "toolsNotRunning"} | Measure-Object).Count)"
    $vmtoolshwdata | Export-CSV ".\$($vcenter)-vmtoolshw.csv" -notypeinfo
}
#endregion

#region VM CD Rom State, v2
if($gathervmcdromdata){
    write-log -Message "Gathering VM CD-Rom State..." -Severity Info
    $vmcdromfiles = @()
    $i = 1
    $vmswithconnectedcdroms = $virtualmachines | Where-Object {$_.Runtime.PowerState -eq "PoweredOn"} | Where-Object {$_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualCdrom] -AND $_.Connectable.Connected}}
    $count = ($vmswithconnectedcdroms | Measure-Object).Count
    foreach ($thisvm in $vmswithconnectedcdroms) {
        $thiscdrominfo = New-Object PSObject
        Write-Progress -Activity "Gathering CDROM Data... $($thisvm.Name)" -PercentComplete (($i*100)/$count) -Status "$i of $count - $(([math]::Round((($i)/$count * 100),0))) %"
        $thiscdrominfo = Get-CDDrive -VM $thisvm.Name -Server $vcenter | Select-Object Parent,IsoPath,ConnectionState
        $vmcdromfiles += $thiscdrominfo
        $i++
    }
    Clear-Variable -Name thisvm
    Add-Content -Path $summaryfile -Value "Connected CD-Roms: `t`t`t $(($vmswithconnectedcdroms | Measure-Object).Count)"
    $vmcdromfiles | Export-CSV ".\$($vcenter)-cdromstate.csv" -notypeinfo
    Write-Progress -Activity "Gathering CDROM Data..." -Completed
}
#endregion

#region Gather VMs with Time Configured, v2
if($gathervmswithtimesync){
    write-log -Message "Gathering VMs with Host Time Sync" -Severity Info
    $vmstimesyncstatus = $virtualmachines | Select-Object Name,@{N='SyncStatus';E={$_.Config.Tools.SyncTimeWithHost}},@{N="ToolsStatus";E={$_.Guest.ToolsStatus}}
    $vmssynctrue = $vmstimesyncstatus | Where-Object {$_.SyncStatus -eq $true }
    $vmtimesynctruelist = @()
    $i = 0
    $vmssynctruecount = $vmssynctrue.count
    foreach($vm in $vmssynctrue){
        $vmname = $vm.Name
        Write-Progress -Activity "Gathering time Sync info for: $vmname ..." -PercentComplete (($i*100)/$vmssynctruecount) -Status "$i of $vmssynctruecount - $(([math]::Round((($i)/$vmssynctruecount * 100),0))) %"
        $thisvm = New-Object -TypeName PSCustomObject
        $esx = (Get-VMHost -VM $vmname).Name
        $clustername = (Get-Cluster -VM $vmname).Name
        $timediff = (Get-Date) -  ([datetime]((Get-VMHost $esx | Get-ESXCLI -v2).System.Time).Get.Invoke())
        $thisvm | Add-Member -MemberType NoteProperty -Name Name -Value $vmname
        $thisvm | Add-Member -MemberType NoteProperty -Name VMHost -Value $esx
        $thisvm | Add-Member -MemberType NoteProperty -Name Cluster -Value $clustername
        $thisvm | Add-Member -MemberType NoteProperty -Name ToolsStatus -Value $vm.ToolsStatus
        $thisvm | Add-Member -MemberType NoteProperty -Name Timedrift -Value $timediff
        $vmtimesynctruelist += $thisvm
        $i++
    }
    
    $vmtimesynctruelist | Export-csv ".\$($vcenter)-vmtimedrift.csv" -notypeinfo
    $vmstimesyncstatus | Export-CSV ".\$($vcenter)-vmtimesyncstatus.csv" -notypeinfo
    Add-Content -Path $summaryfile -Value "VMs Syncing Time w/ Host: `t`t $(($vmstimesyncstatus | Where-Object {$_.SyncStatus -eq $true } | Measure-Object).Count)"
}
#endregion

#region Host PwrMgmt, v2
if($gatherhostpwrdata){
    write-log -Message "Gathering Power Mgmt Status of Cluster..." -Severity Info
    $clusterpwrstatedata = $hostinfo | Select-Object Name, @{N='Power Technology';E={$_.Hardware.CpuPowerManagementInfo.HardwareSupport}}, @{N='Current Policy';E={$_.Hardware.CpuPowerManagementInfo.CurrentPolicy}}
    $clusterpwrstatedata | Export-CSV ".\$($vcenter)-clusterpwrmgmt.csv" -notypeinfo
}
#endregion

#region NTP Config, v2
if($gatherhostntpdata){
    write-log -Message "Gathering NTP Config..." -Severity Info
    $ntpdata = $hostinfo | Sort-Object Name | Select-Object Name, @{N="NTPServer";E={$_.Config.DateTimeInfo.NtpConfig.Server}}
    Add-Content -Path $summaryfile -Value "Hosts Missing NTP Config: `t`t $(($ntpdata | Where-Object {$_.NTPServer -eq $null } | Measure-Object).Count)"
    $ntpdata | Export-CSV ".\$($vcenter)-hostntpdata.csv" -notypeinfo
}
#endregion

#region Host Syslog Config, v2
if($gatherhostsyslog){
    write-log -Message "Gathering Host Syslog Config..." -Severity Info
    $syslogdata = $hostinfo | Sort-Object Name | Select-Object Name, @{N="SyslogLogHost";E={($_.Config.Option | Where-Object {$_.Key -eq "Syslog.global.logHost"}).value    }}
    Add-Content -Path $summaryfile -Value "Hosts Missing Syslog Config: `t`t $(($syslogdata | Where-Object {$_.SyslogLogHost -eq $null}).Count)"
    $syslogdata | Export-CSV ".\$($vcenter)-hostsyslogdata.csv" -notypeinfo
}

#endregion

#region Host AD Config, v2
if($gatherHostADConfig){
    Write-log -Message "Gathering Host AD Config..." -Severity Info
    $hostadconfig = $hostinfo | Select-Object Name,@{N="DomainJoinEnabled";E={($_.Config.AuthenticationManagerInfo.AuthConfig | Where-Object {$_ -is [VMware.Vim.HostActiveDirectoryInfo]}).Enabled}},@{N="JoinedDomain";E={($_.Config.AuthenticationManagerInfo.AuthConfig | Where-Object {$_ -is [VMware.Vim.HostActiveDirectoryInfo]}).JoinedDomain}}
    Add-Content -Path $summaryfile -Value "Non-DomainJoined Hosts: `t`t $(($hostadconfig | Where-Object { $_.DomainJoinEnabled -eq $false } | Measure-Object).Count)"
    $hostadconfig | Export-CSV ".\$($vcenter)-hostdomainjoinstatus.csv" -notypeinfo
}


#endregion

#region Cluster HA Status, v2
if($gatherclusterhadata){
    write-log -Message "Gathering HA Status of Cluster..." -Severity Info
    $clusterhastatusdata = $clusterinfo | Sort-Object name | Select-Object Name,@{N="HAEnabled";E={$_.Configuration.DasConfig.Enabled}},@{N="HAAdmissionStatus";E={$_.Configuration.DasConfig.AdmissionControlEnabled}}
    Add-Content -Path $summaryfile -Value "Clusters with HA Off: `t`t`t $(($clusterhastatusdata | Where-Object {$_.HAEnabled -eq $false } | Measure-Object).Count)"
    Add-Content -Path $summaryfile -Value "Clusters with HA Admission Off: `t`t $(($clusterhastatusdata | Where-Object {$_.HAAdmissionStatus -eq $false } | Measure-Object).Count)"
    $clusterhastatusdata | Export-CSV ".\$($vcenter)-clusterhastatus.csv" -notypeinfo
}
#endregion

#region Host Multipath
if($gatherhostmultipathdata){
    write-log -Message "Gathering Host Multipathing Info..." -Severity Info
    $hostmultipath = $hostinfov1 | Get-ScsiLun -LunType disk -Server $vcenter | Select-Object VMHost,CanonicalName,MultipathPolicy,IsLocal | Where-Object { $_.MultipathPolicy -notlike "RoundRobin" -and $_.IsLocal -eq $FALSE }
    Add-Content -Path $summaryfile -Value "Hosts with Fixed Path Devices: `t`t`t $(($hostmultipath | Select-Object -Unique VMHost | Measure-Object).Count)"
    $hostmultipath | Export-CSV ".\$($vcenter)-multipath.csv" -notypeinfo
}
#endregion

#region VFMS Datastore Info, v2
if($gathervmfsversiondata){
    write-log -Message "Gathering Datastore Info..." -Severity Info
    $vmfsdatastoredata = $datastoreinfo | Select-Object Name,@{N="DatastoreCluster";E={Get-DatastoreCluster -Datastore $_.Name}},@{N="Type";E={$_.Info.VMFS.Type}},@{N="VMFSVersion";E={$_.Info.VMFS.MajorVersion}},@{N="BlockSizeMB";E={$_.Info.VMFS.BlockSizeMb}},@{N="CapacityGB";E={[math]::Round(($_.Summary.Capacity)/1GB,2)}},@{N="FreeSpaceGB";E={[math]::Round(($_.Summary."FreeSpace")/1GB,2)}},@{N="UsedGB";E={[math]::Round((($_.Summary.Capacity)-($_.Summary."FreeSpace"))/1GB,2)},@{N="VolumeID";E={$_.Info.VMFS.Extent}}}
    if(($vmfsdatastoredata | Where-Object {$_.Type -eq "VMFS" -AND $_.VMFSVersion -eq "5" } | Measure-Object).Count -eq 0){
        write-log -Message "No VMFS Volumes Found. Possible NFS volumes exist. Check Report."
    }
    else{
        Add-Content -Path $summaryfile -Value "VMFS5 Datastores: `t`t $(($vmfsdatastoredata | Where-Object { $_.VMFSVersion -eq "5" } | Measure-Object).Count)"
    }
    $vmfsdatastoredata | Export-CSV ".\$($vcenter)-vmfsdatastoredata.csv" -notypeinfo
}
#endregion

#region Legacy Network Adapters
if($gatherlegacynicdata){
    write-log -Message "Gathering VM w/o VMXNET3..." -Severity Info
    $vmlegacyadapter = $virtualmachines | Get-NetworkAdapter -Server $vcenter | Select-Object @{N='VM';E={$_.Parent.Name}},@{N='AdapterName';E={$_.Name}},@{N='Type';E={$_.Type}}
    Add-Content -Path $summaryfile -Value "Count of Non-VMXNET3 VMs: `t`t $(($vmlegacyadapter | Where-Object { $_.Type -ne "VMXNET3" } | Select-Object -Unique VM | Measure-Object).Count)"
    $vmlegacyadapter | Export-CSV ".\$($vcenter)-e1000vms.csv" -notypeinfo
}
#endregion

#region Legacy SCSI Adapters - In Progress
if($gatherlegacyscsidata){
    write-log -Message "Gathering VM SCSI Adapters..." -Severity Info
    $vmscsiadapters = $virtualmachines | Where-Object {$_.Runtime.PowerState -eq "PoweredOn"} | Where-Object {$_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualSCSIController]}}
    Add-Content -Path $summaryfile -Value "Count of Non-LSI SAS/PVSCSI VMs: `t`t $(($vmscsiadapters | Where-Object { ($_.Summary -like "*LSI Logic*")} | Select-Object -Unique Parent | Measure-Object).Count)"
    $vmscsiadapters | Export-CSV ".\$($vcenter)-vmscsiadapters.csv" -notypeinfo
}
#endregion

#region Cluster Oversubscription
if($gatherclusteroversubdata){
    #$virtualmachines.Config.Hardware.NumCPU
    write-log -Message "Gathering cluster oversubscription data..." -Severity Info
    $clusteroversubdata = $clusterinfo | Sort-Object name | Select-Object Name, @{N="CpuOversubscriptionFactor";E={[math]::Round((($_|get-VM| Where-Object {$_.PowerState -eq "PoweredOn"} | Measure-Object numcpu -sum).Sum)/(($_ | get-vmhost | Measure-Object numcpu -sum).sum)/1,2)}}
    Add-Content -Path $summaryfile -Value "Clusters oversubscribed: `t`t $(($clusteroversubdata | Where-Object {$_.CpuOversubscriptionFactor -gt $oversubscriptionfactor} | Measure-Object).Count)"
    $clusteroversubdata | Export-CSV ".\$($vcenter)-oversub.csv" -notypeinfo
}
#endregion


write-host "`n"

#Write-Host "% Hosts not in High Perf: `t" -NoNewline
#$clusterhastatusdata.

Get-Content -Path $summaryfile

Write-host "`nRAW Data dumped to directory: $($pwd.Path)`n"
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $initialTimeout -Confirm:$false | Out-Null

if(-not $continue){
    # This will leave the existing VI server connection running if it existed before running this script. 
    disconnect-viserver -confirm:$false
}