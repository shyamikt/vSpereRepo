$vmNames = Import-Csv -Path .\BO3.csv -UseCulture
#$vmNames.Port_group_name

foreach($portG in $vmNames){

Get-VMHost | Get-VirtualSwitch -Name “vSwitch0” | New-VirtualPortGroup -Name $portG.Port_group_name -VLanId $portG.vlan

#Get-VMHost "esx-086.pearsoncmg.com" | Get-VirtualPortGroup -Name $portG.Port_group_name | Remove-VirtualPortGroup



}