# Check ESXi Host Devices against VMware IO HCL
# Does not use live VMware HCL data, but a copied JSON based version
# Needs to be connected to a vCenter Server (Connect-VIServer)
# Does not upload any sensitive information. Downloads a full HCL copy and compares it locally.
#
# The script uses Get-EsxCli -V2 which requires at least PowerCLI 6.3 R1
#
# Author: Florian Grehl - www.virten.net

# Configure device scope. Change the $devices variable to match the host you want to check.
# You can check multiple hosts at once, but please note that the Script needs to call esxcli 
# to identify driver and firmware versions. This can take about 20-40 seconds per host.
$devices = Get-VMHost | Get-VMHostPciDevice | where { $_.DeviceClass -eq "MassStorageController" -or $_.DeviceClass -eq "NetworkController" -or $_.DeviceClass -eq "SerialBusController"} 

# Uncomment this line to enable debug output
#$DebugPreference = "Continue"

$hcl = Invoke-WebRequest -Uri http://www.virten.net/repo/vmware-iohcl.json | ConvertFrom-Json
$AllInfo = @()
Foreach ($device in $devices) {

  # Ignore USB Controller
  if ($device.DeviceName -like "*USB*" -or $device.DeviceName -like "*iLO*" -or $device.DeviceName -like "*iDRAC*") {
    continue
  }

  $DeviceFound = $false
  $Info = "" | Select VMHost,Cluster,ESXI_Version,ESXI_Build,Model, NumCpu, ProcessorType, DeviceName, VendorName, DeviceClass, vid, did, svid, ssid, Driver, DriverVersion, FirmwareVersion, VibVersion, Supported, Reference
  $Info.VMHost = $device.VMHost
  $Info.Cluster = $device.VMHost.parent
  $Info.ESXI_Version = $device.VMHost.version
  $Info.ESXI_Build = $device.VMHost.build
  $Info.Model = $device.VMHost.Model
  $Info.NumCpu = $device.VMHost.NumCpu
  $Info.ProcessorType = $device.VMHost.ProcessorType
  $Info.DeviceName = $device.DeviceName
  $Info.VendorName = $device.VendorName
  $Info.DeviceClass = $device.DeviceClass
  $Info.vid = [String]::Format("{0:x4}", $device.VendorId)
  $Info.did = [String]::Format("{0:x4}", $device.DeviceId)
  $Info.svid = [String]::Format("{0:x4}", $device.SubVendorId)
  $Info.ssid = [String]::Format("{0:x4}", $device.SubDeviceId)

  # Search HCL entry with PCI IDs VID, DID, SVID and SSID
  Foreach ($entry in $hcl.data.ioDevices) {
    If (($Info.vid -eq $entry.vid) -and ($Info.did -eq $entry.did) -and ($Info.svid -eq $entry.svid) -and ($Info.ssid -eq $entry.ssid)) {
      $Info.Reference = $entry.url
      $DeviceFound = $true
    } 
  }
  
  if($DeviceFound){
    if ($device.DeviceClass -eq "NetworkController"){
      # Get NIC list to identify vmnicX from PCI slot Id
      $esxcli = $device.VMHost | Get-EsxCli -V2
      $niclist = $esxcli.network.nic.list.Invoke();
      $vmnicId = $niclist | where { $_.PCIDevice -like '*'+$device.Id}
      <#$Info.Device = $vmnicId.Name#>
      
      # Get NIC driver and firmware information
      #Write-Debug "Processing $($Info.VMHost.Name) $($Info.Device) $($Info.DeviceName)"
      if ($vmnicId.Name){      
        $vmnicDetail = $esxcli.network.nic.get.Invoke(@{nicname = $vmnicId.Name})
        $Info.Driver = $vmnicDetail.DriverInfo.Driver
        $Info.DriverVersion = $vmnicDetail.DriverInfo.Version
        $Info.FirmwareVersion = $vmnicDetail.DriverInfo.FirmwareVersion
      
        # Get driver vib package version
        Try{
          $driverVib = $esxcli.software.vib.get.Invoke(@{vibname = "net-"+$vmnicDetail.DriverInfo.Driver})
        }Catch{
          $driverVib = $esxcli.software.vib.get.Invoke(@{vibname = $vmnicDetail.DriverInfo.Driver})
        }
        $Info.VibVersion = $driverVib.Version
      }
    
    } elseif ($device.DeviceClass -eq "MassStorageController" -or $device.DeviceClass -eq "SerialBusController"){
      # Identify HBA (FC or Local Storage) with PCI slot Id
      # Todo: Sometimes this call fails with: Get-VMHostHba  Object reference not set to an instance of an object.
      $vmhbaId = $device.VMHost |Get-VMHostHba -ErrorAction SilentlyContinue | where { $_.PCI -like '*'+$device.Id} 
      #$Info.Device = $vmhbaId.Device
      $Info.Driver = $vmhbaId.Driver
         

      # Get driver vib package version
      Try{
        $driverVib = $esxcli.software.vib.get.Invoke(@{vibname = "scsi-"+$vmhbaId.Driver})
      }Catch{
        $driverVib = $esxcli.software.vib.get.Invoke(@{vibname = $vmhbaId.Driver})
        $vmhbaId.Driver
      }
      $Info.driverVersion = $driverVib.Version
    }
  $Info.Supported = $DeviceFound
  $AllInfo += $Info
  }
}

# Display all Infos
#$AllInfo

# Display ESXi, DeviceName and supported state
#$AllInfo |select VMHost,Device,DeviceName,Supported,Reference |ft -AutoSize

# Display device, driver and firmware information
$AllInfo |select VMHost,Cluster,ESXI_Version,ESXI_Build,DeviceName,DeviceClass,Driver,DriverVersion,FirmwareVersion,VibVersion |ft -AutoSize

$exportTo = ($global:DefaultVIServer).name.split(".")[0]+" - IO-Device-Report.csv"

#Export to CSV
$AllInfo |select VMHost,Cluster,ESXI_Version,ESXI_Build,Model, NumCpu, ProcessorType,DeviceName,DeviceClass,Driver,DriverVersion,FirmwareVersion,VibVersion| Export-Csv -NoTypeInformation Patch_Automation/$exportTo

<# Export to HTML
$css  = "table{ Margin: 0px 0px 0px 4px; Border: 1px solid rgb(200, 200, 200); Font-Family: Tahoma; Font-Size: 8pt; Background-Color: rgb(252, 252, 252); }"
$css += "tr:hover td { Background-Color: #6495ED; Color: rgb(255, 255, 255);}"
$css += "tr:nth-child(even) { Background-Color: rgb(242, 242, 242); }"
Set-Content -Value $css -Path IO-Device-Report.css
$AllInfo | ConvertTo-Html -CSSUri "IO-Device-Report.css" | Set-Content "IO-Device-Report.html"#>