
$pumuser = ""
$pumpass = ""
$keyword = "dn1upcoreesx53m"
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

$pass =(Invoke-RestMethod "$baseURI/passwordvault/api/accounts/$id/password/retrieve" -Method 'POST' -Headers $headers -Body $bodygetpass | ConvertTo-Json).trim('"')

