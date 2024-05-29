
Param(
	[Parameter(Mandatory=$true, HelpMessage="Host list path")]
	[string]$hostlistpath,
 
	[Parameter(Mandatory=$true, HelpMessage="PUM user")]
	[string]$pumuser,
    
    [Parameter(Mandatory=$true, HelpMessage="PUM Password")]
    [string]$pumpass,

	[Parameter(Mandatory=$true, HelpMessage="vCenter URL")]
	[string]$vCenter,

    [Parameter(Mandatory=$true, HelpMessage="vCenter URL")]
	[string]$vcuser,

    [Parameter(Mandatory=$true, HelpMessage="vCenter URL")]
	[string]$vCpass

    
)


function retrivepumpass {
    Param(
    [Parameter(Mandatory=$true)]
    [string]$keyword
    )

                            
    $baseURI = "https://pum.pearson.com"
    $reason =  "ESXi Maintenance"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", "application/json")

    $bodyauth = "{`n	`"username`": `"$pumuser`",`n	`"password`": `"$pumpass`",`n	`"concurrentSession`": `"true`"`n}"

    $apitoken = (Invoke-RestMethod "$baseURI/passwordvault/api/Auth/LDAP/logon" -Method 'POST' -Headers $headers -Body $bodyauth | ConvertTo-Json).trim('"')


    $headers.Add("Authorization", $apitoken)

    $res = Invoke-WebRequest "$baseURI/passwordvault/api/accounts?search=$keyword" -Method 'GET' -Headers $headers 
    $id = (ConvertFrom-Json -InputObject $res.Content  | Select-Object -ExpandProperty "value").id
    $bodygetpass = "{`n    `"reason`": `"$reason`",`n    `"TicketId`": `"`",`n    `"ActionType`": `"show`"`n}"

    $global:pass =(Invoke-RestMethod "$baseURI/passwordvault/api/accounts/$id/password/retrieve" -Method 'POST' -Headers $headers -Body $bodygetpass | ConvertTo-Json).trim('"')
    

    }
    #write-host "Validating input $hostlistpath, $vCenter, $pumuser, $pumpass"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
write-host "Connecting VC"

try{
    $null = $error
($vc = Connect-VIServer -server $($vCenter) -User $vcuser -Password $vcpass) > $null 2>&1
}
catch{"Error"}
if ($error){
    Write-Host "$error" -ForegroundColor Red
    break
}
write-host "Conneted " -foregroundcolor Green -NoNewline
write-host "$vc"
import-csv -path $hostlistpath |ForEach-Object{ 
    $null = $error
    try{
        write-host "Retriving PUM Password for $($_.host)"
    retrivepumpass -keyword $_.host
    write-host "$($_.host) " -NoNewline
    write-host "password retrieved: " -BackgroundColor Green -NoNewline
    write-host "$pass"
    }
    catch { "Error" }
    if (!$error){
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



      