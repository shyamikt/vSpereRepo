############# Created by Sahan Fernando for the Pearson Virtualization team ###############################
############# Script to get IP and FQDN information of all VMs in a vCenter  ######################
# ******* Inputs
#	vCenter name and credentials required
	

Connect-VIServer $server -user $user_name -password $pwd -ErrorAction SilentlyContinue | out-null


	foreach($vm_name in get-vm){
		write-host "Fetching information of $vm_name"
		$vm = Get-VM $vm_name
		$power_state = $vm.PowerState
		if($power_state -eq "PoweredOff"){
			$vm_ip = "NA"
			$vm_fqdn = "NA"
		}

		else{
			$vm_ip = $vm.Guest.IPAddress -join ','
			$vm_fqdn = $vm.ExtensionData.Guest.IPStack[0].DnsConfig.HostName
		}


		$details = @{
			Virtual_Machine = $vm_name
			vCenter = $VC
			Power_state = $power_state
			IP = $vm_ip
			FQDN = $vm_fqdn
		} 

		Write-Host "Creating result object for $VC"
		$results += New-Object PSObject -Property $details 

	}


	
	Write-Host "Exporting CSV for $VC"
	$results | export-csv -Path .\$vc_number.csv
	$vc_number = $vc_number + 1
	Disconnect-VIServer * -confirm:$false			
}



#write host log
$hostlog | Export-Csv -append Pearson_host_list.csv -NoTypeInformation


