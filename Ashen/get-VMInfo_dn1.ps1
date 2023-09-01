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
                ToolsInstalled = "N/A"
                ToolsVersion = "N/A"
            }

    $OutArray += New-Object PSObject -Property $details
    continue
    
}



$tools = $main | Select Name,version,@{Name="ToolsVersion";Expression={$_.ExtensionData.Guest.ToolsVersion}},@{Name="ToolsStatus";Expression={$_.ExtensionData.Guest.ToolsVersionStatus}}

$bus = $main | Get-ScsiController | select bussharingmode

$details = @{

                Name = $vm
                HW_version = $tools.version
                ToolsInstalled = $tools.ToolsStatus
                ToolsVersion = $tools.ToolsVersion
            }

    $OutArray += New-Object PSObject -Property $details



}
$outarray | export-csv "VMInfo.csv"