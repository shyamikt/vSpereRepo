$metrics = "virtualdisk.read.average","virtualdisk.write.average" 
$vm = Get-VM 'icdudautmcpl01'
$start = (Get-Date).AddHours(-4)

$controllerTab = @{}
$vm | Get-ScsiController | %{
    $controllerTab.Add($_.ExtensionData.BusNumber,$_.Name)
}

$diskTab = @{}
$vm | Get-HardDisk | %{
    $diskTab.Add($_.UnitNumber,$_.Name)
}

$stats = Get-Stat -Entity $vm -Stat $metrics -Start $start 
$stats | Group-Object -Property Instance | %{
    New-Object PSObject -Property @{
        VM = $_.Group[0].Entity.Name
        Controller = $controllerTab[[int]($_.Name.Split(':')[0].TrimStart('scsi'))]
        Disk = $diskTab[[int]($_.Name.Split(':')[1])]
        AvgRead = ($_.Group | where {$_.MetricId -eq "virtualdisk.read.average"} | Measure-Object -Property Value -Average).Average
        AvgWrite = ($_.Group | where {$_.MetricId -eq "virtualdisk.write.average"} | Measure-Object -Property Value -Average).Average
    }
}