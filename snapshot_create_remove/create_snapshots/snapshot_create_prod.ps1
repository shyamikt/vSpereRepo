#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########


$vmlist = get-content "vmlist.txt"

$vcenter = #vcenter name
$snapshot_name = #snapshot name eg: "CHG490854"
$snapshot_description = #description for the snapshot - if not needed just comment the variable/ leave blank - eg ""



	Connect-VIServer $vcenter 

	foreach($vm in $vmlist){

		Get-VM -name $vm | new-Snapshot -name $snapshot_name -description $snapshot_description -confirm:$false
	}
	


		Disconnect-VIServer * -confirm:$false
