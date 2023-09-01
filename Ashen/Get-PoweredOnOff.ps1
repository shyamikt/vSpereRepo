Import-Module Get-VIEventsFaster 

#$servers = get-content "Servers.txt"

#foreach(){


$VMinQuestion = Get-VM aumelbas329

$VMinQuestion | Get-VIEventsFaster -EventType @("VmPoweredOnEvent","DrsVmPoweredOnEvent")

#}