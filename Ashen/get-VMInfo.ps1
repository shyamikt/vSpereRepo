$servers = get-content "servers.txt"
$OutArray = @()

foreach($vm in $servers){

try{
$main = get-vm $vm  -ErrorAction stop 

}

catch{

    $details = @{

                Name = $vm
                HW_version = "N/A"
                usedSpaceGB = "N/A"
                ProvisionedSpaceGB = "N/A"
                BusSharingMode = "N/A"
            }

    $OutArray += New-Object PSObject -Property $details
    continue
    
}
$main = $main |  Select-Object -First 1

$info = $main | select name, version, usedSpaceGB, ProvisionedSpaceGB

$bus = $main | Get-ScsiController | select bussharingmode

$details = @{

                Name = $vm
                HW_version = $info.version
                usedSpaceGB = $info.usedSpaceGB
                ProvisionedSpaceGB = $info.ProvisionedSpaceGB
                BusSharingMode = $bus.bussharingmode
            }

    $OutArray += New-Object PSObject -Property $details



}
$outarray | export-csv "VMInfo.csv"