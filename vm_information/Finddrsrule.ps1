$ErrorActionPreference= 'silentlycontinue'
$tbl = @()
$list = Get-Content ".\vmlist.txt"
 foreach($line in $list){
    Write-Host "Checking $($line)"
    $row = "" | Select-Object VM, Cluster, Redhat
    $row.vm = $line  
    $drsrule = Get-DrsClusterGroup -vm $line 
    if ($drsrule -eq $null){
        $vm1 = Get-vm $line 
        If($vm1 -eq $null){
            $row.Cluster = "Not in vCenter"
            $row.Redhat = "N/A"
            $tbl += $row
            Write-Host "$($row)"
            Continue

        }
        $row.Cluster = (Get-Cluster -vm $line)
        $row.Redhat = "No Redhat Rule"
        $tbl += $row
        Write-Host "$($row)"
        Continue


    }
    
  
    $row.Cluster = (Get-DrsClusterGroup -vm $line).Cluster
    $row.Redhat = (Get-DrsClusterGroup -vm $line).Name 

    $tbl += $row
    Write-Host "$($row)"
}

$tbl | FT 