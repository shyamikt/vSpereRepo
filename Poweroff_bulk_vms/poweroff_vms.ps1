#Connect-VIServer

$vmlist = Get-Content ".\Poweroff_bulk_vms\vmlist.txt"

foreach ($vm in $vmlist){
           $gvm = Get-VM $vm -ErrorAction Ignore

    if ($gvm -ne $null){ 
        if ($gvm.PowerState -eq "PoweredOff"){
            Write-Host "Removing $vm "
            ($gvm | Remove-VM -DeletePermanently -Confirm:$false)
        } else {
                        Write-Host "$vm | $($gvm.PowerState) "
                    }

} else {
    Write-Host "No VM found named $($vm)"
}
}