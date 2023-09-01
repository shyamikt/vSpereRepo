$Servers = get-content "Servers.txt"
$OutArray = @()
foreach($vm in $servers){

$disk = Get-VM $vm | Select-Object Name,NumCpu, MemoryGB, ProvisionedSpaceGB

        $details = @{

                VM_Name = $disk.Name
                Disk_Space = $disk.ProvisionedSpaceGB
                CPU = $disk.NumCpu
                Memory_GB = $disk.MemoryGB
            }

            $OutArray += New-Object PSObject -Property $details
}

$outarray | export-csv "somefile.csv"




