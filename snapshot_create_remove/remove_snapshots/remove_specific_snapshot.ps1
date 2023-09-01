#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########


$vm_list = Get-Content "vm_list.txt"

$vcenter = #vcenter name

$usr = #enter user name
$pwd = #enter password

$snapshot_name = #enter the name of the snapshot to delete

Connect-VIServer $vcenter -user $usr -password $pwd


foreach($vm_name in $vm_list){

	Get-VM -Name $vm_name | Get-Snapshot -Name $snapshot_name | Remove-Snapshot

}

Disconnect-VIServer * -confirm:$false


