# Connect to vCenter Server
Connect-VIServer -Server Your-vCenter-Server -User Your-Username -Password Your-Password

# Get all powered on VMs without a CD/DVD drive
$vmsWithoutCD = Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" -and (Get-CDDrive -vm $_.name).Count -eq 0 -and $_.name -notmatch "vcls"}

# Loop through each VM and add a CD/DVD drive
foreach ($vm in $vmsWithoutCD) {
    $vmName = 'uk1usnmatapp01'
    $vm = Get-VM -Name $vmName
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $dev1 = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $dev1.Operation = [VMware.Vim.VirtualDeviceConfigSpecOperation]::add
    $cd = New-Object VMware.Vim.VirtualCdrom
    $cd.Key = -1
    $cd.ControllerKey = -2
    $cd.Backing = New-Object VMware.Vim.VirtualCdromRemotePassthroughBackingInfo
    $cd.Backing.DeviceName = ''
    $dev1.Device = $cd
    $spec.DeviceChange += $dev1
    $dev2 = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $dev2.Operation = [VMware.Vim.VirtualDeviceConfigSpecOperation]::add
    $ctrl = New-Object VMware.Vim.VirtualAHCIController
    $ctrl.Key = -2
    $dev2.Device = $ctrl
    $spec.DeviceChange += $dev2
    $vm.ExtensionData.ReconfigVM($spec)
}

# Disconnect from vCenter Server
Disconnect-VIServer -Confirm:$false
#######################################################

