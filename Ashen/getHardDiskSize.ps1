$vmNames = Import-Csv -Path .\Orphaned.csv -UseCulture
$OutArray = @()

foreach($rec in $vmNames){

    $data = Get-Datastore $rec.datastore
    new-PSDrive -Location $data -Name ds -PSProvider VimDatastore -Root '\' > $null
    $a = Get-ChildItem -Path ds: -Recurse -Filter $rec.Orphaned_VMDK | Select *
    Remove-PSDrive -Name ds -Confirm:$false

    $details = @{

                Hard_Disk = $rec.Orphaned_VMDK
                length = $a.length
                Disk_Size_GB = [math]::round($a.length/1GB,3)
                Last_Write_Time = $a.LastWriteTime
                Path = $a.DatastoreFullPath
                Datastore = $a.Datastore
            }

    $OutArray += New-Object PSObject -Property $details

}

$outarray | export-csv "OrphanedVMDK.csv"