function get-vminventory
{
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

        Get-ESXIODevice -ExportCSV "C:\Users\resmon.ICDWPCOREAPP30\desktop\Patch_automation"    



        $discvi = disconnect-viserver -server * -force -confirm:$false
    }

    $vSphereLicInfo |Select Name, Key, Total, Used,Information | Export-Csv -NoTypeInformation $filename
}


get-vminventory  