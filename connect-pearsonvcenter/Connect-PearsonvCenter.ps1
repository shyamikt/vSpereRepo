#####
#
# Usage: 'Dot' source this script in your PowerShell profile.
#
#
#
#####

Function Connect-PearsonvCenter {
    try{
        $vcenters = Invoke-RestMethod -URI http://icdwpvirtapp01.dcsprod.dcsroot.local/vcenters.json 
    }
    catch{
        write-warning -Message "Unable to pull vCenter List. Connect to VPN first and try again."
        throw $_
    }
    $vcenterlist = ($vcenters | Out-Gridview -OutputMode Single -Title "Select vCenter.").FQDN
    #if($vcenter.count -gt 1){
    #    write-warning "You are connecting to multiple vCenters at the same time. Are you sure you want to do this?"
    #    write-host "Connecting to $($vcenterlist.Count) vCenter(s)..."
    #    Set-PowerCLIConfiguration -
    #}
    foreach($singlevcenter in $vcenterlist){
        write-host "Connecting to $($singlevcenter)..."
        $domain = $singlevcenter.Split(".")[1]
        switch($domain){
            "dcsprod" {
                write-host "Found DCSUTIL vCenter"
                if(-not $dcscred) { $dcscred = Get-Credential -Message "Enter your DCSUTIL Credentials"}
                connect-viserver $singlevcenter -cred $dcscred
            }
            "wrk" {
                write-host "Found WRK vCenter"
                if(-not $wrkcred) { $wrkcred = Get-Credential -Message "Enter your WRK Credentials"}
                connect-viserver $singlevcenter -cred $wrkcred
            }
            "ecollege*"{
                write-host "Found Athens vCenter"
                if(-not $athenscred) { $athenscred = Get-Credential -Message "Enter your WRK Credentials"}
                connect-viserver $singlevcenter -cred $athenscred
            }
            default {
                connect-viserver $singlevcenter -cred (Get-Credential -Message "Enter your creds for $singlevcenter")
            }
        }
    }
}