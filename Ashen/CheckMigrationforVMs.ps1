$OutArray = @()
$VMs = Get-VM

## get the ServiceInstance object
$viewSI = Get-View 'ServiceInstance'
## get the VMProvisioningChecker object
$viewVmProvChecker = Get-View $viewSI.Content.VmProvisioningChecker


foreach($vm in $VMs){

    $cluster = $vm | get-cluster

    $Hosts = get-cluster | Get-VMHost
   
    foreach($hosted in $hosts){
    
       if ($hosted.name -ne $vm.vmhost.name){

                $destHost = $hosted
       }
            
    }
    ## query the VMotion Compatibility
    $result = $viewVmProvChecker.QueryVMotionCompatibilityEx($vm.Id,$destHost.Id)

    if($RESULT.error){
        $details = @{

                    VM = $vm.name
                    Current_Host = $vm.vmhost.name
                    Destination_Host = $destHost.name
                    Warning = $result.warning
                    Error = $result.error
                }

        $OutArray += New-Object PSObject -Property $details
    }
    $outArray


}

$exportTo = ($global:DefaultVIServer).name.split(".")[0]+" - VMotionErrors.csv"
$outarray | export-csv Patch_Automation/$exportTo




<#
## name of VM to check for VMotion compatibility
$strMyVMNameToCheck = "ContentDev - SMEUser1"
## name of destination VMHost to check for VMotion compatibility for this VM
$strMyVMHostNameToCheck = "icdupcertesx01m.dcsutil.dcsroot.local"

## get the ServiceInstance object
$viewSI = Get-View 'ServiceInstance'
## get the VMProvisioningChecker object
$viewVmProvChecker = Get-View $viewSI.Content.VmProvisioningChecker






## query the VMotion Compatibility
$viewVmProvChecker.QueryVMotionCompatibilityEx((Get-VM $strMyVMNameToCheck).Id, (Get-VMHost $strMyVMHostNameToCheck).Id) #>