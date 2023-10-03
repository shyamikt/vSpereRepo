#$vmlist = Get-Content C:\tmp\inputFile.txt

foreach ($vmName in ((Get-VM "*" | where { $_.PowerState -eq "PoweredOff"}))){
#Write-Host "Quering $($vmName.name)......"
Get-HardDisk -VM $vmName | Select-Object -first 1 -PipelineVariable hd | ForEach-Object -Process {

    $dsName,$path = $hd.Filename.Split(' ')
    $ds = Get-Datastore -Name $dsName.Trim('[]')
    New-PSDrive -Location $ds -Name DS -PSProvider VimDatastore -Root '\' | Out-Null
    $LastWriteTime = Get-ChildItem -Path "DS:$path" | select -Property LastWriteTime 
    Remove-PSDrive -Name DS -Confirm:$false 


    } | select @{n="VM Name";e={$vmName}}, @{n="LastWriteTime";e={$LastWriteTime}} #| Export-CSV c:\tmp\last-accsess.csv -Append -NoTypeInformation -Force
 }