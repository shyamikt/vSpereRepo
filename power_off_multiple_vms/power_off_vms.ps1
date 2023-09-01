#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########


$vm_list = Get-Content "vm_list.txt"

$vcenter = #vcenter name

$usr = #enter user name
$pwd = #enter password


Connect-VIServer $vcenter -user $usr -password $pwd


foreach($vm_name in $vm_list){

	$vm = Get-VM -Name $vm_name 

	if($vm.PowerState -eq "PoweredOff"){
		write-host "$vm is already powered off"
		Continue
	}

	else{
		write-host "Stopping $vm"
		Stop-VM -VM $vm -Confirm:$false
	}

	
	
}

Disconnect-VIServer * -confirm:$false


