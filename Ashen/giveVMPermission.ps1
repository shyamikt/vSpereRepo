#$servers = get-content "servers.txt"

foreach($vm in $servers){


Get-VM -Name $vm | New-VIPermission -Role (Get-VIRole -Name "Console User +Start/Stop-VM") -Principal "DCSUTIL\EMEA_EDX_Application_Support_Hellaby_offshore"

}