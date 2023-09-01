function get-vminventory
{
    $filename="LicenseInformation.csv"
    $vSphereLicInfo= @()
    $viCntinfo = Import-Csv .\custviservers.csv
    foreach ($vi in $viCntInfo)
    {
        try{
            $convi = connect-viserver -server $vi.viserver -username $vi.username -password $vi.password -ErrorAction Stop
        }
        catch{

            $ErrorMessage = $_.Exception.Message
            $details = @{

                    Vcenter = $vi.viserver
                    Connection = "Failed"
                    Notes = $ErrorMessage
               
                }
         
            $OutArray += New-Object PSObject -Property $details
            continue
        }

       $ServiceInstance=Get-View ServiceInstance
        $LicenseMan=Get-View $ServiceInstance.Content.LicenseManager
        
        Foreach ($License in $LicenseMan.Licenses){
           $Details="" |Select Name, Key, Total, Used,Information
           $Details.Name=$License.Name
           $Details.Key=$License.LicenseKey
           $Details.Total=$License.Total
           $Details.Used=$License.Used
           $Details.Information=$License.Labels |Select-expandValue
           $vSphereLicInfo+=$Details
        }      



        $discvi = disconnect-viserver -server * -force -confirm:$false
    }

    $vSphereLicInfo |Select Name, Key, Total, Used,Information | Export-Csv -NoTypeInformation $filename
}


get-vminventory 


