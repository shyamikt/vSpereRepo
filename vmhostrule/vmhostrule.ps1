
$list = Get-Content ".\vmhostrule\vmlist.txt" 
foreach ($vm in $list ){New-DrsClusterGroup -Name "host_grp_$($vm)" -VMHost "$(Get-VMHost -VM "$($vm)")" -Cluster "$(Get-cluster -vm "$($vm)")" 
New-DrsClusterGroup -Name "vm_grp_$($vm)" -VM "$($vm)" -Cluster "$(Get-cluster -vm "$($vm)")" 
New-DrsVMHostRule -Name "rule_$($vm)" -Cluster "$(Get-cluster -vm "$($vm)")" -VMGroup "vm_grp_$($vm)" -VMHostGroup "host_grp_$($vm)" -Type "MustRunOn" -Enabled $true}

