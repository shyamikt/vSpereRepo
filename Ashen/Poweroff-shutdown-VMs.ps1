foreach($vmName in (Get-Content -Path .\servers.txt)){

    $vm = Get-VM -Name $vmName

    if($vm.Guest.State -eq "Running"){

        Shutdown-VMGuest -VM $vm -Confirm:$false

    }

    else{

        Stop-VM -VM $vm -Confirm:$false

    }

}