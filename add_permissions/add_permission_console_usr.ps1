############# Created by Sahan Fernando for the Pearson Virtualization team ###############################
############# Script to add bulk permissions for a user on multiple virtual machines ######################
# ******* Inputs
#	Put the list of virtual machines in a txt file called vm_list.txt separated by a new line


$vmList = Get-Content "vm_list.txt"

#Credentials 
$user_dcsutil = <user_name_here>
$pwd_dcsutil = <password_here>

$server = <vcenter_name_here>
$permission_user = "dcsutil\afernsa" #user for permissions
$role = "Console User" #Role name
	
Connect-VIServer $server -User $user_dcsutil -Password $pwd_dcsutil

foreach($vm in $vmList){
	write-host "adding permission to $vm"
	New-VIPermission -Role $role -Principal $permission_user -Entity $vm

}


 

