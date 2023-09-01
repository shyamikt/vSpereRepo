# Get data about vmdk and format
#
# Niklas Åkerlund / RTS

Connect-VIServer "icdwpcorevcs41.dcsprod.dcsroot.local"

$VMs = Get-Cluster "Iowa City VUE UCS POD" | Get-VM *
$Data = @()
 
 foreach ($VM in $VMs){
    $VMDKs = $VM | get-HardDisk
    foreach ($VMDK in $VMDKs) {
        if ($VMDK -ne $null){
            $CapacityGB = $VMDK.CapacityKB/1024/1024
            $CapacityGB = [int]$CapacityGB
            $into = New-Object PSObject
            Add-Member -InputObject $into -MemberType NoteProperty -Name VMname $VM.Name
			Add-Member -InputObject $into -MemberType NoteProperty -Name VMX $vm.ExtensionData.config.files.VMpathname
            Add-Member -InputObject $into -MemberType NoteProperty -Name Datastore $VMDK.FileName.Split(']')[0].TrimStart('[')
            Add-Member -InputObject $into -MemberType NoteProperty -Name VMDK $VMDK.FileName.Split(']')[1].TrimStart('[')
            Add-Member -InputObject $into -MemberType NoteProperty -Name StorageFormat $VMDK.StorageFormat
            Add-Member -InputObject $into -MemberType NoteProperty -Name CapacityGB $CapacityGB
            $Data += $into
        }
    }

}

$Data | Sort-Object VMname,Datastore,VMDK | Export-Csv -Path D:\Template_script\Iowa-City-VUE-UCS-POD-15032019.csv -NoTypeInformation