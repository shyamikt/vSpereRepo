

$vmList = Get-Content ".\VM_snaps\vmlist.txt"

foreach ($vmName in $vmList) {
    # Get the VM object
    $vm = Get-VM -Name $vmName
    
    # Take snapshot with comment
    $snapshotName = "INC0344569"
    $comment = "The snapshots can be deleted after 25th April 2024"
    New-Snapshot -VM $vm -Name $snapshotName -Description $comment
}