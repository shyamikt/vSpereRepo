$VMs = Get-Content "servers.txt"
 $start = (Get-Date).AddDays(-1)
 

foreach ($VM in $VMs) {
 

get-vm $vm | Get-VIEvent -MaxSamples ([int]::MaxValue) -Start $start |

where{$_ -is [VMware.Vim.VmPoweredOffEvent] -or $_ -is [VMware.Vim.VMPoweredOnEvent]} |

Select CreatedTime,@{N='VM';E={$_.Vm.Name}},@{N='Type';E={$_.GetType().Name}} Export-CSV -NoTypeInformation "PoweredOffVMs_info_EW.csv" -Append

 

   }