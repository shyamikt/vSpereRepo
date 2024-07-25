$vcenternames = "dn1wpcorevcs01.dcsprod.dcsroot.local", "icdwpcorevcs41.dcsprod.dcsroot.local"
$dcsutilusername = "serv.pchvspheredata@dcsutil.dcsroot.local"
$vmnamephase = "us1"

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
 
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Info','Warning','Error')]
        [string]$Severity = 'Info',

        [Parameter()]
        [switch]$noconsole = $false
    )
    if(!$noconsole)
    {
        if($Severity -ne "Info"){
            Write-Warning "$(Get-Date -f s) - $message"
        }
        Else {
        Write-Host "$(Get-Date -f s) - $message"
        }
    }
    Add-Content -Path "$pwd\log.txt" -Value "$(Get-Date -f s) $severity $message"
}
write-log -Message "Starting script task $(get-date)" -Severity Info
    foreach($vc in $vcenternames){
        $nodrsautovms = $null
        try{
        write-log -Message "Connecting to $vc" -Severity Info

        $SecureString = Get-Content "..\..\encryptedcreds\$dcsutilusername.cred" | ConvertTo-SecureString
        $Credential = New-Object System.Management.Automation.PSCredential($dcsutilusername, $SecureString)
        Connect-VIserver -Server $vc -Credential $Credential -ErrorAction Stop
    }catch{
        write-log -Message "Connection to $vc failed! `n`n $_" -Severity Error
        disconnect-viserver -confirm:$false
        exit;
    }
        
    $nodrsautovms = get-vm | Where-Object {($_.name -like "$($vmnamephase)*") -and ($_.DrsAutomationLevel -eq "AsSpecifiedByCluster")} #| select Name, @{n="Cluster";e={Get-Cluster -vm $_.name}} | Format-Table
    Write-Log -Message "$($nodrsautovms.count) vms are eligible for DRS OverRide." -Severity Info
   # if($null -ne $nodrsautovms) {
   #     foreach($vm in $nodrsautovms){
   #         try{
   #         Set-vm $vm -DrsAutomationLevel Disabled -Confirm:$false
   #         Write-Log -Message "Set $($vm) DRS Automation Level to Disabled." -Severity Info
   #        }
   #         catch{
   #             Write-log -Message "Setting DRS Automation Level failed on $($vm).`n $($Error[0]) "
   #         }
   #     }
   # }else{
   #      
   #     Continue
   # }

    disconnect-viserver -confirm:$false
    write-log -Message "Disonnecting $vc" -Severity Info
    }
    write-log -Message "Ending script task $(get-date)" -Severity Info


