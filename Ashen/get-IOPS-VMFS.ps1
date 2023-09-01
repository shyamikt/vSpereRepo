﻿$metrics = "disk.numberwrite.summation","disk.numberread.summation"
$start = (Get-Date).AddMinutes(-5)
$report = @()
$vms = get-cluster BO3-Resource-Cluster-02-PROD | Get-VM | where {$_.PowerState -eq "PoweredOn"}
$stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start
$interval = $stats[0].IntervalSecs
$lunTab = @{}
foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
$ds.ExtensionData.Info.Vmfs.Extent | %{
$lunTab[$_.DiskName] = $ds.Name
}
}
$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
New-Object PSObject -Property @{
VM = $_.Values[0]
Disk = $_.Values[1]
IOPSWriteAvg = ($_.Group | `
where{$_.MetricId -eq "disk.numberwrite.summation"} | `
Measure-Object -Property Value -Average).Average / $interval
IOPSReadAvg = ($_.Group | `
where{$_.MetricId -eq "disk.numberread.summation"} | `
Measure-Object -Property Value -Average).Average / $interval
Datastore = $lunTab[$_.Values[1]]
}
}
$report

$metrics = "disk.numberwrite.summation","disk.numberread.summation"
$start = (Get-Date).AddMinutes(-5)
$report = @()
 
$vms = Get-VM | where {$_.PowerState -eq "PoweredOn"}
$stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start
$interval = $stats[0].IntervalSecs
 
$lunTab = @{}
foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
	$ds.ExtensionData.Info.Vmfs.Extent | %{
		$lunTab[$_.DiskName] = $ds.Name
	}
}
 
$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
	New-Object PSObject -Property @{
		VM = $_.Values[0]
 		Disk = $_.Values[1]
 		IOPSWriteAvg = ($_.Group | `
			where{$_.MetricId -eq "disk.numberwrite.summation"} | `
 			Measure-Object -Property Value -Average).Average / $interval
 		IOPSReadAvg = ($_.Group | `
			where{$_.MetricId -eq "disk.numberread.summation"} | `
 			Measure-Object -Property Value -Average).Average / $interval
		Datastore = $lunTab[$_.Values[1]]
	}
}
 
$report| export-csv ./report-VMFS.csv