#Create the array

$array = @()

$vms =  get-vm (get-content "servers.txt")

#Loop for BusSharingMode

foreach ($vm in $vms)

{

$disks = $vm | Get-ScsiController | Where-Object {$_.BusSharingMode -eq ‘Physical’ -or $_.BusSharingMode -eq ‘Virtual’}

    foreach ($disk in $disks){

    $REPORT = New-Object -TypeName PSObject

    $REPORT | Add-Member -type NoteProperty -name Name -Value $vm.Name

    $REPORT | Add-Member -type NoteProperty -name VMHost -Value $vm.Host

    $REPORT | Add-Member -type NoteProperty -name Mode -Value $disk.BusSharingMode

    $REPORT | Add-Member -type NoteProperty -name Type -Value “BusSharing”

    $array += $REPORT

    } 

}

$array | export-csv "DiskSharedVMs.csv"	