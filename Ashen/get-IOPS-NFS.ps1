
$metrics = "virtualdisk.numberwriteaveraged.average","virtualdisk.numberreadaveraged.average"
$start = (Get-Date).AddMinutes(-5)
$report = @()
 
$vms = get-cluster BO3-Resource-Cluster-02-PROD | Get-VM | where {$_.PowerState -eq "PoweredOn"}
$stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start
$interval = $stats[0].IntervalSecs
 
$hdTab = @{}
foreach($hd in (Get-Harddisk -VM $vms)){
    $controllerKey = $hd.Extensiondata.ControllerKey
    $controller = $hd.Parent.Extensiondata.Config.Hardware.Device | where{$_.Key -eq $controllerKey}
    $hdTab[$hd.Parent.Name + "/scsi" + $controller.BusNumber + ":" + $hd.Extensiondata.UnitNumber] = $hd.FileName.Split(']')[0].TrimStart('[')
}
 
$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
    New-Object PSObject -Property @{
        VM = $_.Values[0]
        Disk = $_.Values[1]
        IOPSMax = ($_.Group | `
            Group-Object -Property Timestamp | `
            %{$_.Group[0].Value + $_.Group[1].Value} | `
            Measure-Object -Maximum).Maximum / $interval
        Datastore = $hdTab[$_.Values[0] + "/"+ $_.Values[1]]
    }
}
 
$report| export-csv ./report-NFS.csv