$vmhost=$esxcli=$vib=$null
foreach ($vmhost in ((get-vmhost "*"| where {($_).ConnectionState -ne "NotResponding" }| sort name).name )){
    $esxcli = get-vmhost $VMHost | Get-EsxCli -V2
        $vib = $esxcli.software.vib.list.Invoke() | Where {($_.id -like "*fnic*")-or($_.id -like "*nenic*")} | select ID
        Write-Host "=========$($vmhost)=========" 
        $vib.ID
        
    }