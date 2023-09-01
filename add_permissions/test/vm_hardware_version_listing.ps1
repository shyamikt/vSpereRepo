$vm_list = Get-Content "dn3stglist.txt"
$vc = "dn3wscorevcs01.ecollegeqa.net"
#$vm_name = "TestVM2"

#connect with the DB
$secpasswd = ConvertTo-SecureString "54321" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("st2user2", $secpasswd)

#Connect with the database
Connect-MySqlServer -Credential $mycreds -ComputerName 'icdupautmapp04.pearsontc.com' -Database vm_hardware_upgrade



Connect-VIServer $vc -user "administrator@vsphere.local" -password "M@nDr4k3!#"

foreach($vm_name in $vm_list){


	$vm_info = Get-VM $vm_name
	$vm_host_info = Get-VMHost -VM $vm_name
	
	
	$vm_power_status = $vm_info.PowerState
	$vm_vmtools_status = $vm_info.ExtensionData.Config.tools.ToolsVersion
	$vm_hwversion = $vm_info.Version
	$a,$vm_hwversionno = $vm_hwversion -split ('v')
	$vm_hwversionno = $vm_hwversionno -as [int]
	
	$host_version = $vm_host_info.Version

	$query_result = Invoke-MySqlQuery  -Query "SELECT * FROM recommended_versions WHERE esx_version = '$host_version'"
	$recommended_hw_version = $query_result.Item("hw_version")


	
	write-host "$vm_name is $vm_power_status. Tools version is $vm_vmtools_status. Hardware Version is $vm_hwversion and recommended version is $recommended_hw_version"
	write-host "Host is at $host_version version"

	if($recommended_hw_version -gt $vm_hwversionno){
		Write-Host "Needs upgrade"
		Invoke-MySqlQuery  -Query "INSERT INTO source_data (vmName,currentVersion,vcenter,recommendedVersion,esxi) VALUES ('$vm_name','$vm_hwversionno','$vc','$recommended_hw_version','$host_version')"
	}

	else{
		Write-Host "Does not need upgrade"
	}

}









