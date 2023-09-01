#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########


$vm_list = Get-Content "vm_list.txt"

$vcenter = #vcenter name
$usr = #user name
$pwd = #password

Connect-VIServer $vcenter -user $usr -password $pwd


foreach($vm_name in $vm_list){

	Get-VM -Name $vm_name | Get-Snapshot | Remove-Snapshot

}

Disconnect-VIServer * -confirm:$false
