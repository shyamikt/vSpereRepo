#Connect-VIServer 
$usr = "dcsutil\asmitke" #"PEROOT\VMALIMO", "PEROOT\VPURIHO", "PEROOT\VSACHRA", "PEROOT\VSIN478" , "PEROOT\VSULEMO" , "PEROOT\VWRIGAD"    #(eg: peroot\vjeyapa or dcsutil\ajeyapa)
$role = "Console User +start or Stop VM"  #"Mod Prog_Console User+Start/Stop VM"
get-vm |?{$_.name -like "ctx*"} | foreach { 
    foreach ($user in $usr) {Get-VM $_ | New-VIPermission -Role (Get-VIRole -Name $($role)) -Principal $($user) -Propagate $true | select Entity, Principal, Role}
}
