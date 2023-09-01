$Servers = get-content "Servers.txt"
$snapName = "TASK0487545"
$description = "Server Support sg8upvmtuapp03"

foreach ($vm in $Servers){

    $server = get-vm $vm
        
    $server | new-snapshot -Name $snapName -Description $description


}