#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########

#### Gets hot plug, hot add status of a virtual machine and exports to a CSV ######
#### Add the vms needed in the vm_list.txt file separated by a new line  ######


$vm_list = Get-Content "vm_list.txt"


$vcenter = #vcenter name

Connect-VIServer $vcenter 

	foreach($vm_name in $vm_list){

	
		$Result = (Get-VM | select ExtensionData).ExtensionData.config | Select Name, MemoryHotAddEnabled, CpuHotAddEnabled, CpuHotRemoveEnabled
		$Result | Export-Csv -append hot_add_list.csv -NoTypeInformation

	}
