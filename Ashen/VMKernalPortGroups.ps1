$vmNames = Import-Csv -Path .\BO3VMKernal.csv -UseCulture
#$vmNames.Port_group_name

foreach($portG in $vmNames){

$label = $portG.Label

    Switch($label){

        VMotion{

            #Vmotion 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet -VMotionEnabled:$true
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

        Management{

            #Management 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet #-ManagementTrafficEnabled:$true
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

        NFS-Staging{

            #NFS-Staging 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet 
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

        NFS-Non-Prod{

            #NFS-Non-Prod 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet 
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

        NFS-Prod{

            #NFS-Prod 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

        FT{

            #FT 
            New-VMHostNetworkAdapter -VMHost $portG.Hostname -PortGroup $portG.PortGroupName -VirtualSwitch $portG.VSwitch -IP $portG.New_IP -SubnetMask $portG.Subnet -FaultToleranceLoggingEnabled:$true
            #set VLAN
            get-vmhost $portG.Hostname | Get-VirtualPortGroup -Name $portG.PortGroupName | Set-VirtualPortGroup -VLanId $portG.New_VLAN    

        }

    }

}