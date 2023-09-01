#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########

#### Extends a specific disk of a virtual machine (in bulk)  ######
#### Add the vms needed in the vm_list.txt file separated by a new line  ######



$vm_list = Get-Content "vm_list.txt"

$vcenter = #vcenter name
$space_to_increase = 20
$hard_disk_to_increase = "Hard Disk 1" #change this to change the increasing disk

Connect-VIServer $vcenter 


	foreach($vm_name in $vm_list){
		write-host "Fetching information of $vm_name"
		$vm = Get-VM $vm_name

		$vm_info_dsk = (Get-HardDisk -VM $vm_name | Where-Object {$_.Name -eq $hard_disk_to_increase}).CapacityGB

		Write-Host "$vm $hard_disk_to_increase is $vm_info_dsk"

		$new_capacity = $vm_info_dsk + $space_to_increase

		Write-Host "new hard disk capacity $new_capacity"

		Get-HardDisk -VM $vm_name | Where-Object {$_.Name -eq $hard_disk_to_increase} | Set-HardDisk -capacityGB $new_capacity -confirm:$false

		$vm_info_dsk = (Get-HardDisk -VM $vm_name | Where-Object {$_.Name -eq $hard_disk_to_increase}).CapacityGB

		Write-Host "$vm new $hard_disk_to_increase is $vm_info_dsk"
	}
	
	Disconnect-VIServer -Confirm:$false








