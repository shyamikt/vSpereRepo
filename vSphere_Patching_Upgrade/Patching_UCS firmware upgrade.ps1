
<#
.SYNOPSIS
  Script to update Cisco UCS Firmware on VMware based blades in a rolling update manner, by VMware cluster
.DESCRIPTION
  User provides vSphere cluster, hostname pattern, and UCS Host Firmware Policy name.
  The script will sequentially check if each host is running the requested firmware.
  If not running the desired firmware, the host will be put into maintenance, shut down,
  UCS firmware update applied, and then powered on and taken out of maintenance mode
  This repeats until all hosts in the cluster have been updated.
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  None
.OUTPUTS
  None

.EXAMPLE
  Run script, being prompted for all input, but no updates installed
  .\UpdateEsxi&UCSFw.ps1
  Run script, providing all needed input including baseline to install updates
  .\UpdateEsxi&UCSFw.ps1 -ESXiCluster "Cluster1" -ESXiHost "*" -FirmwarePackage "3.2.3d." -baseline "3.2.3d Drivers"
  Run script, being prompted for baselines to install updates
  .\UpdateEsxi&UCSFw.ps1 -PromptBaseline
#>



[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False, HelpMessage="ESXi Cluster to Update")]
	[string]$ESXiCluster,
 
	[Parameter(Mandatory=$False, HelpMessage="ESXi Host(s) in cluster to update. Specify * in quotes for all hosts or as a wildcard")]
	[string]$ESXiHost,
    
    [Parameter(Mandatory=$False, HelpMessage="Name of Update Manager baseline to apply or * in quotes for all attached baselines and 999 to skip updates")]
    [string]$Baseline,

	[Parameter(Mandatory=$False, HelpMessage="UCS Host Firmware Package Name")]
	[string]$FirmwarePackage
)

function disconnect (){	
	#Disconnect all the connections
	Write-Host "Clear connections!!"  -foregroundcolor Magenta
	Disconnect-VIServer -force -Confirm:$false > $null 2>&1
	If ($upgrade -ne 1 ){
	Disconnect-Ucs > $null 2>&1}
}

function clearerror (){
$error.clear()
}

function DisableAlarm
{
    #disable alarms for the host
    $alarmMgr = Get-View AlarmManager 
    $alarmMgr.EnableAlarmActions($vmhost.Extensiondata.MoRef,$false)
}

function EnableAlarm
{
   #disable alarms for the host
    $alarmMgr = Get-View AlarmManager 
    $alarmMgr.EnableAlarmActions($vmhost.Extensiondata.MoRef,$true)
}

function BootIso
{		do{
		Write-Host "You can manually upgrade ESXi using iso file or continue with Baseline. Press" -nonewline -foregroundcolor Magenta
		Write-Host " [C] "  -nonewline
		Write-Host "to Continue or any other key to exit." -foregroundcolor Magenta
		$c = Read-Host
			
		} until ( $c -eq "c" )
		
		Write-Host "VC: Continueing script !!!" -foregroundcolor Yellow
		

}

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds 180000 -confirm:$False | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 


########################################
# Selecting Criteria
########################################

Write-host "Available Update Options"
Write-host " 1.	Esx Upgrade only"
Write-host " 2.	UCS Blade Firmware Upgrade only"
Write-host " 3.	Esx Upgrade along with the UCS Blade Firmware Upgrade"

do {
$upgrade = Read-Host "Please enter your choice"
}until (($upgrade -eq 1) -or ($upgrade -eq 2) -or ($upgrade -eq 3))

Write-host $upgrade

########################################
# Importing Modules
########################################
clearerror #Calling function
try {
 Write-Host "Importing required modules......" #-ForegroundColor Green
    Import-Module VMware.PowerCLI > $null 2>&1
	Import-Module VMware.VumAutomation > $null 2>&1
	If ($upgrade -ne 1 ){
	Import-Module Cisco.UCSManager > $null 2>&1
	}
	}
	catch { "Error" }
if  (!$error) {
#if (((get-module vmware.powercli).version.Major -eq "12") -and ((get-module vmware.powercli).version.Minor -eq "3")){
 Write-Host "Successfully Powershell Modules " -ForegroundColor Green
 Write-Host "VMware.PowerCLI"
 #}else {Write-Host "This automation required VMware PowerCli 12.3 !!!" -ForegroundColor Red
 #break
 #}
 If ($upgrade -ne 1 ){
 Write-Host "Cisco.UCSManager"
 }
 } else {
 Write-Host "********Error in importing modules !!" -ForegroundColor Red
 break
	}		
disconnect

########################################
# Connecting to vCenter and UCS Manager
########################################
	
clearerror	#Calling function



try {
$vc = Read-host "Please enter vCenter FQDN or IP"
 Write-Host "Connecting to vCenter......." #-ForegroundColor Green
 $visc = (Connect-VIServer -server $($vc) ).Name > $null 2>&1
 
 If ($upgrade -ne 1 ){
 $um = Read-host "Please enter UCS Manger FQDN or IP"
 Write-Host "Connecting to UCS Manager......." #-ForegroundColor Green 
 $ucsc = (Connect-Ucs -Name $($um) ).Name > $null 2>&1
 }
} 
catch { "Error" }
if  (!$error) {
 Write-Host "Successfully connected to " -ForegroundColor Green
  Write-Host "vCenter $vc " -ForegroundColor Green
 If ($upgrade -ne 1 ){ 
 Write-Host "UCS Manager $um " -ForegroundColor Green
 }
 } else {
 Write-Host "********Unable to connect due to invalid Server or Credential !!" -ForegroundColor Red
 Write-Host "$error" -ForegroundColor Red
 break
	}


#############################################
# Listing Available options if not supplied
#############################################
clearerror #Calling function
try {
	Write-host "Please select upgrade method "
	Write-host " 1.	Cluster selection"
	Write-host " 2.	Hosts list"
		
	do {
	$upgrademtd = Read-Host "Please enter your choice"
	}until (($upgrademtd -eq 1) -or ($upgrademtd -eq 2))
	
	Write-host $upgrademtd
	
	if ($upgrademtd -eq 1){
	if ($ESXiCluster -eq "") {
		$x=1
		$ClusterList = Get-Cluster | sort name
		Write-Host "`nAvailable Clusters to update"
		$ClusterList | %{Write-Host $x":" $_.name ; $x++}
		$x = Read-Host "Enter the number of the Cluster for the update"
		$ESXiClusterObject = Get-Cluster $ClusterList[$x-1] 
	}Else {
		$ESXiClusterObject = (Get-Cluster $ESXiCluster).Name
		}
	
	if ($ESXiHost -eq "") {
		Write-Host "`nEnter name of ESXi Host to update. `nSpecify a FQDN, * for all hosts in cluster, or a wildcard such as Server1*"
		$ESXiHost = Read-Host "ESXi Host"
	}
	$VMHosts = ($ESXiClusterObject | Get-VMHost | sort name | Where { $_.Name -like "$ESXiHost"}).name
	}
	if ($upgrademtd -eq 2){
	Write-host "Importing list of host from hostlist_B2.txt"
	$VMHosts = get-content ".\hostlist.txt"

	$ESXiClusterObject = get-vmhost $VMHosts | Get-Cluster
	}
	if (($VMHosts).count -eq 0){ 
		No Esxi hosts match -ErrorAction Stop
	}
	
	if ($Baseline -eq "") {
		$x=1
		$BaselineList = $ESXiClusterObject | get-vmhost | Get-Baseline -Inherit | sort LastUpdateTime -descending
		Write-Host "`nAvailable Update Manager Baselines in this cluster.  `nIf the desired baseline is missing, attach it to the cluster or host and run the script again."
		Write-Host "Enter 999 to skip baseline updates. `n0: All Available Updates"
		$BaselineList | %{Write-Host $x":" $_.name ; $x++}
		$x = Read-Host "Enter the number of the Baseline"
		switch ($x) {
			'0' { $BaselineObject = ($BaselineList).name }
			'999' { $BaselineObject = "" }
			default { $BaselineObject = ($BaselineList[$x-1]).name }
		}
	}

	if ($Baseline -ne "") {
		if ($Baseline -eq '999') { $BaselineObject = "" }
		else { $BaselineObject = $ESXiClusterObject | get-vmhost | Get-Baseline -Inherit $Baseline }
	}
	
	
	If (($FirmwarePackage -eq "")-and ($upgrade -ne 1 )) {
		$x=1
		$FirmwarePackageList = Get-UcsFirmwareComputeHostPack | select name -unique | sort name
		Write-Host "`nHost Firmware Packages available on connected UCS systems"
		$FirmwarePackageList | %{Write-Host $x":" $_.name ; $x++}
		$x = Read-Host "Enter the number of the package for the update"
		$FirmwarePackage = $FirmwarePackageList[$x-1].name
	}  
		
	
	do {
		Write-Host "Any RDM reservation need? [y] or [n]"
		$rdmres = Read-host 
		} until (($rdmres -eq "y" ) -or ($rdmres -eq "n" ))
		if ($rdmres -eq "y" ){
					do {
						Write-Host "Please update device IDs (naa) on .\naalist.txt for RDM Resevation and enter [C] to continue.."
						$cont = Read-host 
						} until (($cont -eq "c" ) -and ((test-path -path ".\naalist.txt") -eq $true ))
					}
	do {
		Write-Host "Any noncompatible vibs to be removed? [y] or [n]"
		$noncomvib = Read-host 
		} until (($noncomvib -eq "y" ) -or ($noncomvib -eq "n" ))
}
 catch { "Error" }
	if  (!$error) { 
			Write-Host "Verifying Data......... "  -foregroundcolor Yellow
			Write-Host "Cluster	:"  -nonewline
			Write-Host " $ESXiClusterObject" -foregroundcolor Green
			Write-Host "Host	:" -nonewline
			Write-Host " $($VMHosts)" -foregroundcolor Green
			Write-Host "Baseline:" -nonewline
			Write-Host " $BaselineObject" -foregroundcolor Green
			if ($upgrade -ne 1 ){
			Write-Host "UCS FW	:" -nonewline
			Write-Host " $FirmwarePackage" -foregroundcolor Green
			}
			Write-Host ""
			Write-Host ""
			Write-Host "Initiating upgrade to $($ESXiClusterObject)........."  -foregroundcolor Yellow
			
			Write-Host ""
			$seconds = 20
			1..$seconds |
			ForEach-Object { $percent = $_ * 100 / $seconds; 						
			Write-Progress -Activity Processing -Status "Processing the data..." -PercentComplete $percent; 						
			Start-Sleep -Seconds 1
			}
	}else {
			Write-Host $error
			Write-Host " Error on collecting data "  -foregroundcolor Red
			Write-Host " Exiting Script "  -foregroundcolor Red
			clearerror
			disconnect
			break
		}


	Write-Host "`nStarting process at $(date)"

 
	$admissionControl = $ESXiClusterObject.HAAdmissionControlEnabled
    
    if($admissionControl -eq $true){
        $ESXiClusterObject | Set-Cluster -HAAdmissionControlEnabled:$false -Confirm:$false > $null 2>&1
        Write-host "HA Admission control is set to disabled in the cluster" 
    }


#####################
# Initiating Upgrade
#####################

$Progress=-1

Foreach ($VMHost in $VMHosts) {
	clearerror #Calling function
	$MacAddr=$ServiceTemplate=$ServiceTemplateToUpdate=$ServiceProfiletoUpdate=$UCShardware=$Maint=$Shutdown=$poweron=$ackuserack=$patchesx=$esxcli=$esxcliRemoveVibArgs=$upgradeucs=$naalist=$null #Emptying variables
       $StartTime = Get-Date

       $Progress++
       Write-Progress -Activity 'Update Process' -CurrentOperation $vmhost.name -PercentComplete (($Progress / $VMHosts.count) * 100)

       if (($VMHost = Get-VMHost $VMHost).ConnectionState -ne "Connected") {
           Write-Host "$($vmhost.name) is not responding.  Skipping host."
           Continue
       }

       Write-Host "Processing $($VMHost.name) at $(date)" -foregroundcolor Yellow
	   If ($upgrade -ne 1 ){
       Write-Host "Correlating ESXi Host: $($VMHost.Name) to running UCS Service Profile (SP)"
     $MacAddr = Get-VMHostNetworkAdapter -vmhost $vmhost -Physical | where {$_.BitRatePerSec -gt 0} | select -first 1 #Select first connected physical NIC
       $ServiceProfileToUpdate =  Get-UcsServiceProfile | Get-UcsVnic |  where { $_.addr -ieq  $MacAddr.Mac } | Get-UcsParent
    $UCSHardware = $ServiceProfileToUpdate.PnDn
	   
   
       Write-Verbose "Validating Settings"
       if ($ServiceProfileToUpdate -eq $null) {
           write-host $VMhost "was not found in UCS.  Skipping host" -foregroundcolor Red
           Continue
       }
       if ((Get-UcsFirmwareComputeHostPack | where {$_.ucs -eq $ServiceProfileToUpdate.Ucs -and $_.name -eq $FirmwarePackage }).count -ne 1) {
           write-host "Firmware Package" $FirmwarePackage "not found on" $ServiceProfileToUpdate.Ucs "for server" $vmhost.name -foregroundcolor Red
           Continue
       }
	   }

       if ($ESXiClusterObject.DrsEnabled -eq $False) {
           Write-Host $ESXiClusterObject.name "does not have DRS enabled.  Automatic maintenance mode is not possible. `nPlease put hosts into maintenace mode manually !!!"  -foregroundcolor Magenta
       }
	   If ($upgrade -ne 1 ){
	   $upgradeucs = ((($ServiceProfileToUpdate | Get-UcsLsmaintAck).OperState -eq "waiting-for-user") -or ($ServiceProfileToUpdate.HostFwPolicyName -ne $FirmwarePackage))
	   }else {$upgradeucs = $False}
	   
	   Write-Host "VC: Checking baseline compliance on ESXi Host: $($VMhost.Name)"
	   Test-compliance -entity $vmhost
	   
	   if (((Get-Baseline $BaselineObject | Get-Compliance -Entity $vmhost ).status -eq "Compliant") -and ($upgradeucs -ne $true) -and (((Get-Baseline $BaselineObject).SearchPatchProduct).replace(' ','') -match ((get-vmhost $vmhost).Version).replace(' ',''))){
		   write-host "VC: ESXi Host: $($VMhost.Name) is compliant with $($BaselineObject)"
		   If ($upgrade -ne 1 ){
		   Write-Host "UCS: ESXi Host: $($VMhost.Name) is running on UCS $($ServiceProfileToUpdate.Ucs) SP: $($ServiceProfileToUpdate.name)"
		   }
		   Write-Host "Skipping $vmhost!!" -foregroundcolor yellow
			continue
	   }
	   
	DisableAlarm #Calling function
	Write-Host "VC: Disabling alarms on  ESXi Host: $($VMHost.Name)"
	Write-Host "VC: Placing ESXi Host: $($VMHost.Name) into maintenance mode"  -foregroundcolor Yellow
 	Write-Host "VC: Waiting for ESXi Host: $($VMHost.Name) to enter Maintenance Mode"
	$Maint = $VMHost | Set-VMHost -State Maintenance 
 
	do {
		Sleep 10
	} until ((Get-VMHost $VMHost).ConnectionState -eq "Maintenance")
       Write-Host "VC: ESXi Host: $($VMHost.Name) now in Maintenance Mode"  -foregroundcolor Yellow

	   if ($noncomvib -eq "y" ){
			$esxcli = get-vmhost $VMHost | Get-EsxCli -V2
			$esxcliRemoveVibArgs = $esxcli.software.vib.remove.CreateArgs()
			$vibnames=$esxcli.software.vib.list.Invoke() | Where {($_.id -like "*hio*")}
	   
	if ($vibnames -ne $null) {
		Write-Host "VC: Removing non-complient vibs on ESXi Host: $($VMHost.Name)"
		ForEach ($vibname in $vibnames) {
			$esxcliRemoveVibArgs.vibname = $vibname.Name
			$esxcli.software.vib.remove.Invoke($esxcliRemoveVibArgs) > $null 2>&1
			}
	} else {Write-Host "VC: There are no non-complient vibs on ESXi Host: $($VMHost.Name)"}
	   }
	 If ( $rdmres -eq "y"){
	$naalist = get-content ".\naalist.txt"
	if ($naalist -eq $empty){
	}else {
		Write-Host "VC: Applying RDM Resevation for $($VMHost)"
		foreach ($naa in $naalist){
		$naares = $esxcli.storage.core.device.setconfig.Invoke(@{device=$($naa);perenniallyreserved="true"})
		Write-Host "	Device $($naa) - PerenniallyReserved $($naares)"
		}
	}
	}



	try {
		If ($upgrade -ne 1 ){
		#Heading to UCS
		if ((($ServiceProfileToUpdate | Get-UcsLsmaintAck).OperState -eq "waiting-for-user") -or ($ServiceProfileToUpdate.HostFwPolicyName -ne $FirmwarePackage)){
	
			Write-Host "VC: ESXi Host: $($VMHost.Name) is now being shut down"  -foregroundcolor Yellow
			$Shutdown = $VMHost.ExtensionData.ShutdownHost($true)
	
			Write-Host "UCS: ESXi Host: $($VMhost.Name) is running on UCS $($ServiceProfileToUpdate.Ucs) SP: $($ServiceProfileToUpdate.name)"
			Write-Host "UCS: Waiting for UCS SP: $($ServiceProfileToUpdate.name) to gracefully power down"
			do {
				if ( (get-ucsmanagedobject -dn $ServiceProfileToUpdate.PnDn -ucs $ServiceProfileToUpdate.Ucs).OperPower -eq "off"){
					break
				}
				Sleep 30
			} until ((get-ucsmanagedobject -dn $ServiceProfileToUpdate.PnDn -ucs $ServiceProfileToUpdate.Ucs).OperPower -eq "off" )
			
			$poweron = $ServiceProfileToUpdate | Set-UcsServerPower -State "down" -Force
			Write-Host "UCS: UCS SP: $($ServiceProfileToUpdate.name) powered down"
	
			if ($ServiceProfileToUpdate.HostFwPolicyName -eq $FirmwarePackage) {
				#Write-Host "UCS: $ServiceProfileToUpdate.name is already running firmware $FirmwarePackage" -foregroundcolor Yellow
			} else {
					if ($ServiceProfileToUpdate.SrcTemplName -eq "" ){
						Write-Host "UCS: Changing Host Firmware pack policy for UCS SP: $($ServiceProfileToUpdate.name) to $($FirmwarePackage)"
						$updatehfp = $ServiceProfileToUpdate | Set-UcsServiceProfile -HostFwPolicyName $FirmwarePackage -Force
						
						Write-Host "UCS: Waiting for UCS SP: $($ServiceProfileToUpdate.name) to complete firmware update process..."
						do 	{
							Sleep 20
						} until ((Get-UcsManagedObject -Dn $ServiceProfileToUpdate.Dn -ucs $ServiceProfileToUpdate.Ucs).AssocState -ieq "associated")
				
						
					} else {
						Write-Host "UCS: UCS SP: $($ServiceProfileToUpdate.name) has a attached Service Template $($ServiceProfileToUpdate.SrcTemplName) !!!"
						$ServiceTemplate = $ServiceProfileToUpdate.SrcTemplName
						$ServiceTemplateToUpdate = (Get-UcsServiceProfile -name $ServiceTemplate)
						
						$updatehfp = $ServiceTemplateToUpdate | Set-UcsServiceProfile -HostFwPolicyName $FirmwarePackage -Force
						Write-Host "UCS: Waiting for UCS SP: $($ServiceProfileToUpdate.SrcTemplName) to complete firmware update process..."
						do 	{
							Sleep 20
							} until ((Get-UcsManagedObject -Dn $ServiceProfileToUpdate.Dn -ucs $ServiceProfileToUpdate.Ucs).AssocState -ieq "associated")
						}
				}
				
				
			Write-Host "UCS: Applied Host Firmware $($FirmwarePackage) to UCS SP: $($ServiceProfileToUpdate.name)."
			$ackuserack = $ServiceProfileToUpdate | get-ucslsmaintack | Set-UcsLsmaintAck -AdminState "trigger-immediate" -Force
			Write-Host "UCS: Acknowledging any User Maintenance Actions for UCS SP: $($ServiceProfileToUpdate.name)"
			
			Write-Host "UCS: Power up UCS SP: $($ServiceProfileToUpdate.name)"
			$poweron = $ServiceProfileToUpdate | Set-UcsServerPower -State "up" -Force
			Write-Host "UCS: SP: $($ServiceProfileToUpdate.name) FSM Inprogress........."
			
			do { 
				$seconds = 20
				1..$seconds |
				ForEach-Object { $percent = $_ * 100 / $seconds; 						
				Write-Progress -Activity Processing -Status "FSM Inprogress..." -PercentComplete $percent; 						
				Start-Sleep -Seconds 1
				}
			} until ((Get-UcsManagedObject -Dn $ServiceProfileToUpdate.Dn -ucs $ServiceProfileToUpdate.Ucs).AssocState -ieq "associated")

	#pausing script to upgrade esx using iso
	 
		BootIso			
		
					Write-Host "VC: Waiting for ESXi: $($VMHost.Name) to connect to vCenter" 
			do {
				$seconds = 20
				1..$seconds |
				ForEach-Object { $percent = $_ * 100 / $seconds; 						
				Write-Progress -Activity Processing -Status "Loading Esxi....." -PercentComplete $percent; 						
				Start-Sleep -Seconds 1
					}
			} until ((Get-VMHost $VMHost).ConnectionState -ne "NotResponding" )	
		} else {
			Write-Host "UCS: $($ServiceProfileToUpdate.name) is already running firmware $FirmwarePackage" -foregroundcolor Yellow
			}

		} #ending UCS part



		if (($upgrade -ne 2 ) -or (((Get-Baseline $BaselineObject).SearchPatchProduct).replace(' ','') -notmatch ((get-vmhost $vmhost).Version).replace(' ',''))){
			if(($noncomvib -eq "y") -or (((Get-Baseline $BaselineObject).SearchPatchProduct).replace(' ','') -notmatch ((get-vmhost $vmhost).Version).replace(' ',''))){
			if ( ((get-VMHost $VMHost).ConnectionState -eq "Maintenance") -and ($vibnames -ne $null)){		
				Write-Host "VC: ESXi Host: $($VMHost.Name) is now being restart"  -foregroundcolor Yellow
				$reboot = get-VMHost $VMHost | restart-VMHost -confirm:$false -force | out-null
				do {
				Sleep 5
				}until ((get-VMHost $VMHost).ConnectionState -eq "NotResponding")
						
				Write-Host "VC: Waiting for ESXi: $($VMHost.Name) to connect to vCenter" 	
					do {
						$seconds = 20
						1..$seconds |
						ForEach-Object { $percent = $_ * 100 / $seconds; 						
						Write-Progress -Activity Processing -Status "Loading Esxi....." -PercentComplete $percent; 						
						Start-Sleep -Seconds 1
						}
					}until ((get-VMHost $VMHost).ConnectionState -eq "Maintenance")
					}
				}
			}

If ($upgrade -ne 2 ){
		#Applying Baseline for Esxi
        if ($BaselineObject -ne "") {
            Write-Host "VC: Installing Updates on host $($VMhost.name)"
			Sleep 10
            #Test-compliance -entity $vmhost
            try {
				$Maint = $VMHost | Set-VMHost -State Maintenance

				foreach ( $base in $BaselineObject) {
					
					Get-Baseline -Name $base | Remediate-Inventory -Entity $VMHost -confirm:$False > $null 2>&1
                }
              	}	
				catch { "Error" }
				if  (!$error) {
				}else {
						Write-Host "VC: Error patching host $vmhost  !!!" -foregroundcolor Red
						Write-Host "VC: $error "				
						Write-Host "VC: Please remediate $($VMHost) manually to continue the upgrade process. Enter " -foregroundcolor Magenta -nonewline
						Write-Host "[C] " -nonewline
						Write-Host "to Continue or any other key to exit" -foregroundcolor Magenta
						$c = Read-Host
						if ($c -eq "c"){
							Write-Host " VC: Continuing script !!!" -foregroundcolor Yellow
							
						}else {
								Write-Host "Finished process with error at $(date)" -ForegroundColor Red
							    if($admissionControl -eq $true){
									$ESXiClusterObject | Set-Cluster -HAAdmissionControlEnabled:$true -Confirm:$false > $null 2>&1
									Write-Host "HA Admission control is back to enabled in the cluster"
								}
								Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds $initialTimeout
								clearerror #Calling function
								disconnect #Calling function
								break
							}
					}
		}
}
        
        Write-host "VC: Exiting maintenance mode on $(date)" -foregroundcolor Yellow
        $Maint = $VMHost | Set-VMHost -State Connected 
		EnableAlarm #Calling function
		clearerror #Calling function
		Write-Host "VC: Enabling alarms on  ESXi Host: $($VMHost.Name)"

        $ElapsedTime = $(get-date) - $StartTime
        write-host "$($VMhost.name) completed in $($elapsedTime.ToString("hh\:mm\:ss"))`n" -ForegroundColor Green
		Sleep 10
}

Catch 
	{
	 Write-Host " Error occurred in script:" -ForegroundColor Red
	 Write-Host ${Error}
	 Write-Host "Please upgrade on $($VMHost) manually and enter" -nonewline -foregroundcolor Magenta
	 Write-Host " [C] "  -nonewline
	 write-host "to Continue or any other key to exit." -foregroundcolor Magenta
	 $c =  Read-Host
	if ($c -eq "c"){
		 Write-Host " VC: Continuing script !!!" -foregroundcolor Yellow
			Continue	
	}else{
		 if($admissionControl -eq $true){
			$ESXiClusterObject | Set-Cluster -HAAdmissionControlEnabled:$true -Confirm:$false > $null 2>&1
			Write-Host "HA Admission control is back to enabled in the cluster"
			}
		
		 Write-Host "Finished process with error at $(date)" -ForegroundColor Red
		 Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds 180 
		 clearerror #Calling function
		 disconnect #Calling function
		 break
		}
	}
}


#############
# Finalizing
#############

    if($admissionControl -eq $true){
        $ESXiClusterObject | Set-Cluster -HAAdmissionControlEnabled:$true -Confirm:$false > $null 2>&1
        Write-Host "HA Admission control is back to enabled in the cluster"
    }
disconnect #Calling function
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds 180 -confirm:$False | Out-Null
Write-Host "Finished process at $(date)" -ForegroundColor Green