$lldp = Foreach ($EsxHost in (Get-Datacenter "UK1 DC"| get-vmhost)){
 
  write-host "Quarying $EsxHost......"
   $Esxcli = Get-Esxcli -vmhost $EsxHost.name -V2
   $EsxcliInfo=$esxcli.network.nic.list.invoke()
   $NetworkView = Get-View ((Get-View $EsxHost).Configmanager.Networksystem)
  
   $vSwitchesNics=@()
   $vSwitches = $EsxHost |Get-VDSwitch
   foreach ($vSwitch in $vSwitches) { 
     if ($vSwitch.nic) {      #VSS Filter
   foreach ($Nic in $vSwitch.nic) {  $vSwitchesNics+= $vSwitch |Select @{N="Name";E={$vSwitch.name}}, @{N="Nic";E={$Nic}}  }
                  }
     elseif ($vSwitch.DataCenter) {    #VDS Filter
   $vSwitchesNics+= $EsxHost | Get-VMHostNetworkAdapter -Physical -DistributedSwitch $vSwitch | Select @{N="Name";E={$vSwitch.name}}, @{N="Nic";E={$_.DeviceName}}
         }
 }
  
   $EsxHost | Get-VMHostNetworkAdapter -Physical | Select @{N="EsxName";E={$_.VMHost}},
   @{N="PnicName";E={$_.DeviceName}},
   @{N="PnicMacAddress";E={$_.Mac}},
   @{N="Link";E={ ($EsxcliInfo | Where Name -eq $_.DeviceName).LinkStatus }},
   @{N="SpeedMb";E={$_.ExtensionData.LinkSpeed.SpeedMb}},
   @{N="vSwitch";E={ ($vSwitchesNics | Where Nic -eq $_.DeviceName).Name } },
   @{N="DProtocol";E={if (($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort) {"CDP"} elseif ( ($NetworkView.QueryNetworkHint($_)).LldpInfo) {"LLDP"} else {"NA"}  }},
   @{N="SwitchName";E={if (($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort) {($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort.DevId}
        elseif (($NetworkView.QueryNetworkHint($_)).LldpInfo) {(($NetworkView.QueryNetworkHint($_)).LldpInfo.Parameter | where key -eq "System Name").Value}  }},
   @{N="SwitchPort";E={if (($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort) {($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort.PortId}
        elseif ( ($NetworkView.QueryNetworkHint($_)).LldpInfo) {($NetworkView.QueryNetworkHint($_)).LldpInfo.PortId}  }},
   @{N="SwitchAddress";E={if (($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort) {($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort.MgmtAddr}
        elseif (($NetworkView.QueryNetworkHint($_)).LldpInfo) {(($NetworkView.QueryNetworkHint($_)).LldpInfo.Parameter | where key -eq "Management Address").Value} }},
   @{N="SwitchId";E={if (($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort) {($NetworkView.QueryNetworkHint($_)).ConnectedSwitchPort.HardwarePlatform}
        elseif ( ($NetworkView.QueryNetworkHint($_)).LldpInfo) {($NetworkView.QueryNetworkHint($_)).LldpInfo.ChassisId}  }},
   @{N="PnicModel";E={ ($EsxcliInfo | Where Name -eq $_.DeviceName).Description }},
   @{N="PnicDriver";E={$_.ExtensionData.Driver}},
   @{N="PciSlot";E={$_.ExtensionData.Pci}}

} 
$lldp | Export-Csv ".\ESXiLLDP_details\getlldpdetail.csv"