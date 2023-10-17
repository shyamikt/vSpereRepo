#### Author : Sahan Fernando ##############
#### Pearson Virtualization team ##########

#### Gets information of a virtual machine - ESX host, ESX cluster, CPU, Memory, Networks, Datastores, shared disk status ######
#### Add the vms needed in the vm_list.txt file separated by a new line  ######


$vm_list = Get-Content ".\vm_information\vm_list.txt"

$vcenter = "bo3wpcorevcs01.wrk.pad.pearsoncmg.com"

Connect-VIServer $vcenter 



$results = @()



	foreach($vm_name in $vm_list){
		write-host "Fetching information of $vm_name"
		$vm = Get-VM $vm_name
		$view = Get-View $vm #-ErrorAction SilentlyContinue
		$settings=Get-AdvancedSetting -Entity $vm_name
		$vm_host = $vm.VMHost
		$vm_cpu = $vm.NumCPU
		$vm_mem = $vm.MemoryGB

		$vm_info_net = Get-NetworkAdapter -VM $vm_name
		$vm_net = $vm_info_net.NetworkName -join ","

		$vm_info_dsk = Get-Datastore -VM $vm_name
		$vm_dsk = $vm_info_dsk.Name -join ","

		$host_info_cluster = Get-Cluster -VMHost $vm_host
		$vm_host_cluster = $host_info_cluster.Name

		
		if ($view.config.hardware.Device.Backing.sharing -eq "sharingMultiWriter" -or $settings.value -eq "multi-writer"){
			write-host " $vm has shared disks"
			$shared_dsk = "True"

		}

		else{
			$shared_dsk = "False"
		}

		$details = @{
			Virtual_Machine = $vm_name
			CPU = $vm_cpu
			Memory_GB = $vm_mem
			Host = $vm_host
			Host_cluster = $vm_host_cluster
			Datastores = $vm_dsk
			Shared_disk_status = $shared_dsk
			Networks = $vm_net

		} #| Select Virtual_Machine, CPU, Memory_GB, Host, Host_cluster, Datastores, Shared_disk_status, Networks

		$results += New-Object PSObject -Property $details 

	}




$results | export-csv StageBO3.csv



Get-Content ".\vm_information\vm_list.txt" | %{Get-VM $_ | Select-Object Name,NumCPU,MemoryGB,@{n="HardDiskSizeGB"; e={[math]::Round((Get-HardDisk -VM $_ | Measure-Object -Sum CapacityGB).Sum)}},@{n="Cluster"; e={(Get-Cluster -VM $_)}}} 

