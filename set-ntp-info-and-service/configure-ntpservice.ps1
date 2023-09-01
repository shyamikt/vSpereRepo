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
        [switch]$noconsole = $false,

        [Parameter()]
        [string]$filedesc = ""
    )
    if(!$noconsole)
    {
        if($severity -eq "Warning"){
            Write-warning "$(Get-Date -f s) - [$Severity] $message"
        }
        elseif($Severity -eq "Error"){
            Write-Host "$(Get-Date -f s) - [$Severity] $message" -ForegroundColor 'Red'
        }
        else{
            Write-Host "$(Get-Date -f s) - [$Severity] $message"
        }
        
    }
    Add-Content -Path "$pwd\$filedesc-log.txt" -Value "$(Get-Date -f s) $severity $message"
}

Clear-Host

### SCRIPT VARIABLES ###
$ntppolicy = "on" # This can be 'on' (start and stop with host), 'off' (Start and stop manually), or 'automatic' (start and stop with port usage)
$ntplist = @(
    'ntp1.pearson.com',
    'ntp2.pearson.com',
    'ntp3.pearson.com'
)
$cleanup = $true #This setting will remove all the previous NTP servers before adding the new ones. Use $false for a new install.
$logfiledescription = "ntpconfig"
#$vmhostscontent = "C:\Users\UCOKEPA\OneDrive - Pearson PLC\Documents\Projects\2022 Projects\VirtInfraRemediation\ntpservers-test.csv" #comment out to use hosts from vCenter
$sleeptime = 5 # Time in seconds to allow NTP to sync on all the hosts. This may not be needed for large clusters.
$maxtimedrift = 30 # Maximum amount of seconds where the time can drift from actual

### END Script Variables ###

# Disconnects from all vCenters for Safety
if($global:DefaultVIServers.Count -gt 0){
    Disconnect-viserver -Server * -Force -Confirm:$false
}

if($null -ne $vmhostscontent ){
    Write-Log -Message "Using CSV for list of hosts. CSV: $vmhostscontent" -Severity Info -filedesc $activevcenter-$logfiledescription
    write-warning "Make sure you're connecting to the vCenter that has the hosts in the CSV."
    $vmhosts = Import-CSV $vmhostscontent
}
Connect-PearsonvCenter # Must have Patricks Connect-PearsonvCenter commandlet loaded

if($null -eq $vmhostscontent){
    Write-Log -Message "Using vCenter for list of hosts" -Severity Info -filedesc $activevcenter-$logfiledescription
    write-host "Select the clusters you wish to configure."
    $clusters = Get-Cluster | Out-GridView -OutputMode Multiple -Title "Select the clusters you wish to configure."
    $vmhosts = $clusters | Get-VMHost | Sort-Object Name
}

# Checks to make sure the connection was successful otherwise the script exits.
if($global:DefaultVIServers.Count -eq 0){
    write-warning -Message "Not connected to a vCenter."
    Exit;
}
$activevcenter = $global:DefaultVIServers.Name

$vmhostcount = $vmhosts.count
if($vmhosts.count -eq 0){
    write-log -Message "No VM Hosts found in list. Exiting..." -Severity Info -filedesc $activevcenter-$logfiledescription
    exit;
}
else{ 
    write-log -Message "Found $vmhostcount hosts across $($clusters.count) cluster(s)." -Severity Info -filedesc $activevcenter-$logfiledescription
    $vmhosts.Name
    Write-host "Review the list of hosts above before continuing"
    do {
        $decision = Read-Host -Prompt "Do you want to continue (Y/N)?"
    } until (($decision -eq 'Y') -or ($decision -eq 'N'))
    if($decision -eq 'N'){
        exit;
    }
}

$i = 1 #Loop iterator

Foreach ($vmhost in $vmhosts)
{
    $esx = $vmhost.name
    Write-Progress -Activity "Configurating NTP on : $esx ..." -PercentComplete (($i*100)/$vmhostcount) -Status "$i of $vmhostcount - $(([math]::Round((($i)/$vmhostcount * 100),0))) %"
    Write-Log -Message "*** STARTING NTP configuration on $esx ***" -Severity Info -filedesc $activevcenter-$logfiledescription
    if($cleanup){
        write-log -Message "NTP server cleanup selected." -Severity Info -filedesc $activevcenter-$logfiledescription
        write-log -Message "Removing previous NTP servers from $esx" -Severity Info -filedesc $activevcenter-$logfiledescription
        try{
            Get-VMHostNtpServer -VMHost $esx | Foreach-Object { Remove-VMHostNtpServer -VMHost $esx -NtpServer $_ -Confirm:$false;write-log -Message "Removed ntp server $_ from $esx" -Severity Info -filedesc $activevcenter-$logfiledescription } | Out-Null
        }
        catch{
            Write-log -Message "Could not remove NTP servers from $esx `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
            $error[0]
        }
    }
        
    # Add NTP servers separately
    Write-log -Message "Setting $($ntplist.count) NTP servers on $esx" -Severity Info -filedesc $activevcenter-$logfiledescription
    try{
        $ntplist | foreach-object { Add-VmHostNtpServer -VMHost $esx -NtpServer $_;write-log -Message "Added ntp server $_ on $esx" -Severity Info -filedesc $activevcenter-$logfiledescription } | Out-Null
    }
    catch{
        write-log -Message "Cloud not add NTP Servers to $esx `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
        $error[0]
    }
    

    # Set the firewall regulation to allow traffic for NTP lookup
    write-log -Message "Setting firewall exception to allow NTP out on $esx" -Severity Info -filedesc $activevcenter-$logfiledescription
    try{
        Get-VMHostFirewallException -VMHost $esx | Where-Object {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true | Out-Null
    }
    catch{
        write-log -Message "Could not set the firewall exception on $esx `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
        $error[0]
    }

    # Start NTP daemon and make it start automatically when needed
    write-log -Message "Starting ntpd on $esx" -Severity Info -filedesc $activevcenter-$logfiledescription
    $ntpservice = Get-VmHostService -VMHost $esx | Where-Object {$_.key -eq "ntpd"}
    if($ntpservice.Running -eq $true){
        try{
            $servicestatus = $ntpservice | Restart-VMHostService -Confirm:$false
        }
        catch{
            write-log -Message "Could not restart NTP service on $esx `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
            $error[0]
        }
    }
    elseif($ntpservice.Running -eq $false){
        try{
            $servicestatus = $ntpservice | Start-VMHostService -confirm:$false
        }
        catch{
            Write-log -Message "Could not start NTP Service on $esx `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
            $error[0]
        }
    }
    # Checking final NTP Service Status
    if($servicestatus.Running -eq $true){
        write-log -Message "NTP service on $esx is $($servicestatus.Running)"-Severity Info -filedesc $activevcenter-$logfiledescription
    }
    else{
        write-log -Message "NTP service on $esx is $($servicestatus.Running)" -Severity Error -filedesc $activevcenter-$logfiledescription
    }
    
    ## Sets the ntp service start up policy to start and stop with the host
    write-log -Message "Setting ntpd startup policy to: $ntppolicy" -Severity Info -filedesc $activevcenter-$logfiledescription
    try{
        Get-VmHostService -VMHost $esx | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy $ntppolicy | Out-Null
    }
    catch{
        write-log -Message "Could not set NTP Host Service policy on $esx. `n $($error[0])" -Severity Error -filedesc $activevcenter-$logfiledescription
        $error[0]
    }
    write-log -Message "*** FINISHED CONFIG ON $esx ***" -Severity Info -filedesc $activevcenter-$logfiledescription

    $i++
}
write-log -Message "*** Sleeping for $sleeptime seconds for NTP to Sync ***" -Severity Info -filedesc $activevcenter-$logfiledescription
Start-Sleep -Seconds $sleeptime
write-log -Message "*** Checking for time drift on hosts ***" -Severity Info -filedesc $activevcenter-$logfiledescription
foreach($vmhost in $vmhosts){
    $esx = $vmhost.name
    write-log -Message "Getting time difference on $esx" -Severity Info -filedesc $activevcenter-$logfiledescription
    $timeonhost = [datetime]((Get-VMHost $esx | Get-ESXCLI -v2).System.Time).Get.Invoke()
    write-log -Message "Time on $esx : $timeonhost" -Severity Info -filedesc $activevcenter-$logfiledescription
    $timediff = (Get-Date) -  ([datetime]((Get-VMHost $esx | Get-ESXCLI -v2).System.Time).Get.Invoke())
    write-log -Message "Time drift for $esx in seconds: $([math]::Round($timediff.TotalSeconds,3))" -Severity Info -filedesc $activevcenter-$logfiledescription
    if($timediff.TotalSeconds -gt $maxtimedrift)
    {
        Write-Log -Message "Time drift for $esx is greather than $maxtimedrift" -Severity Warning -filedesc $activevcenter-$logfiledescription
    }
}

Disconnect-viserver -confirm:$false