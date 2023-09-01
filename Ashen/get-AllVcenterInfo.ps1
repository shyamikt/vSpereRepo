function get-vminventory
{
    $OutArray = @()
    $viCntinfo = Import-Csv .\custviservers.csv
    $k=1       
    $j=1
    foreach ($vi in $viCntInfo)
    {
        try{
            $convi = connect-viserver -server $vi.viserver -username $vi.username -password $vi.password -ErrorAction Stop
        }
        catch{

            $ErrorMessage = $_.Exception.Message
            continue
        }
#######################################################################################################################

$devices = Get-VMHost | Get-VMHostPciDevice | where { $_.DeviceClass -eq "MassStorageController" -or $_.DeviceClass -eq "NetworkController" -or $_.DeviceClass -eq "SerialBusController"} 

# Uncomment this line to enable debug output
#$DebugPreference = "Continue"

$hcl = Invoke-WebRequest -Uri http://www.virten.net/repo/vmware-iohcl.json | ConvertFrom-Json
$AllInfo = @()
Foreach ($device in $devices) {

  $DeviceFound = $false
  $Info = "" | Select VMHost,Cluster,ESXI_Version,ESXI_Build,Model, NumCpu
  $Info.VMHost = $device.VMHost
  $Info.Cluster = $device.VMHost.parent
  $Info.ESXI_Version = $device.VMHost.version
  $Info.ESXI_Build = $device.VMHost.build
  $Info.Model = $device.VMHost.Model
  $Info.NumCpu = $device.VMHost.NumCpu
 

 
  $AllInfo += $Info
 
}

# Display all Infos
#$AllInfo

# Display ESXi, DeviceName and supported state
#$AllInfo |select VMHost,Device,DeviceName,Supported,Reference |ft -AutoSize

# Display device, driver and firmware information
#$AllInfo |select VMHost,Cluster,ESXI_Version,ESXI_Build,DeviceName,DeviceClass,Driver,DriverVersion,FirmwareVersion,VibVersion |ft -AutoSize

$exportTo = $vi.viserver.+" - IO-Device-Report.csv"

#Export to CSV
$AllInfo |select VMHost,Cluster,ESXI_Version,ESXI_Build,Model, NumCpu | Export-Csv -NoTypeInformation $exportTo

#######################################################################################################################       
        $discvi = disconnect-viserver -server * -force -confirm:$false
    }

    #$report | export-csv "esxiInventory.csv"
}


get-vminventory 


