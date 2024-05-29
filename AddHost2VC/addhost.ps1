
Param(
	[Parameter(Mandatory=$true, HelpMessage="Host list path")]
	[string]$hostlistpath,
 
	[Parameter(Mandatory=$true, HelpMessage="PUM user")]
	[string]$pumuser,
    
    [Parameter(Mandatory=$true, HelpMessage="PUM Password")]
    [string]$pumpass,

	[Parameter(Mandatory=$true, HelpMessage="vCenter URL")]
	[string]$vCenter,

    [Parameter(Mandatory=$true, HelpMessage="vCenter user")]
	[string]$vcuser,

    [Parameter(Mandatory=$true, HelpMessage="vCenter password")]
	[string]$vCpass,

    [Parameter(Mandatory=$true, HelpMessage="Esxi default password")]
	[string]$dfltesxipass
   
)

######## Functuin for PUM Password Retrieve ######
function retrivepumpass {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$keyword,
    [Parameter(Mandatory=$true)]
    [string]$dfltesxipass
    )
                            
    $baseURI = "https://pum.pearson.com"
    $reason =  "ESXi Maintenance"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    $bodyauth = "{`n	`"username`": `"$pumuser`",`n	`"password`": `"$pumpass`",`n	`"concurrentSession`": `"true`"`n}"

    $apitoken = (Invoke-RestMethod "$baseURI/passwordvault/api/Auth/LDAP/logon" -Method 'POST' -Headers $headers -Body $bodyauth | ConvertTo-Json).trim('"')

    $headers.Add("Authorization", $apitoken)
    $res = Invoke-WebRequest "$baseURI/passwordvault/api/accounts?search=$keyword" -Method 'GET' -Headers $headers 
    if (((ConvertFrom-Json -InputObject $res.Content  | Select-Object -ExpandProperty "value").count -eq 1) -or ($null -eq (ConvertFrom-Json -InputObject $res.Content  | Select-Object -ExpandProperty "value").count) ) {
    $id = (ConvertFrom-Json -InputObject $res.Content  | Select-Object -ExpandProperty "value").id
    $bodygetpass = "{`n    `"reason`": `"$reason`",`n    `"TicketId`": `"`",`n    `"ActionType`": `"show`"`n}"

    $global:pass =(Invoke-RestMethod "$baseURI/passwordvault/api/accounts/$id/password/retrieve" -Method 'POST' -Headers $headers -Body $bodygetpass | ConvertTo-Json).trim('"')
    write-host "$($keyword) " -NoNewline
    write-host "password retrieved: " -ForegroundColor Green -NoNewline
    write-host "$pass"
    }
    else{
        if(((ConvertFrom-Json -InputObject $res.Content  | Select-Object -ExpandProperty "value").count -eq 0) ){
        Write-Host "No PUM record for $($keyword), using default password" -ForegroundColor Magenta
        $global:pass = $dfltesxipass
        }
        else{
            Write-Host "Too many Records found on PUM, Please do manually" -ForegroundColor Red
            $global:pass = "error"
            
        }
    }
    }
    

write-host "Validating input $hostlistpath, $vCuser, $vcpass, $pumuser, $pumpass"
######## Connecting to vCenter ######
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
$error.clear()
write-host "Connecting to $($vCenter)"

try{
    
($vc = Connect-VIServer -server $($vCenter) -User $vcuser -Password $vcpass ) > $null 2>&1
}
catch{"Error"}
if ($error){
    Write-Host "$error" -ForegroundColor Red
    $error.clear()
    break
}
write-host "Conneted " -foregroundcolor Green -NoNewline
write-host "$vc"

######## Importing host list and their details ######
import-csv -path $hostlistpath |ForEach-Object{ 
    $error.clear()
    try{
    ######## Calling function for Retrieving PUM Password ######
    write-host "Retrieving PUM Password for $($_.host)"
    retrivepumpass -keyword $_.host -dfltesxipass $dfltesxipass

    }
    catch { "Error" }
    if (!$error){
        if($pass -eq "error"){ 
            $error.clear()
            Continue
        }
        ######## Adding host to vCenter using retrieved Password ######
        write-host "Adding $($_.host)"
        $hostadd = Add-vmhost -name $_.host -Location $_.Cluster -User root -Password $pass -Confirm:$false -Force
        Write-Host "Host $($hostadd.name) " -NoNewline
        Write-Host "added successfully " -foregroundcolor Green -NoNewline
        Write-Host "and kept in " -NoNewline
        Write-Host "$($hostadd.ConnectionState) " -ForegroundColor Yellow -NoNewline
        Write-Host "State"
    }
    else{continue}
    
     }



      