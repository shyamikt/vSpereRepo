Connect-VIServer 
$usr = "PEROOT\VMALIMO", "PEROOT\VPURIHO", "PEROOT\VSACHRA", "PEROOT\VSHA259", "PEROOT\VSIN478" , "PEROOT\VSULEMO" , "PEROOT\VWRIGAD"    #(eg: peroot\vjeyapa or dcsutil\ajeyapa)
$role = "Mod Prog_Console User+Start/Stop VM"
get-content ".\VM permission\vmlist.txt" | foreach { 
    foreach ($user in $usr) {Get-VM $_ | New-VIPermission -Role (Get-VIRole -Name $($role)) -Principal $($user) -Propagate $true | select Entity, Principal, Role}
}
