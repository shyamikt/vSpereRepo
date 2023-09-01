function Get-DatastoreFiles{

    param(

        [VMware.VimAutomation.ViCore.Types.V1.VIServer]$Server = $global:DefaultVIServer,

        [string]$DatastoreName,

        [string]$Folder = '',

        [PSCredential]$Credential

    )

 

    $ds = Get-Datastore -Name $DatastoreName -Server $Server

    $dc = Get-VMHost -Datastore $ds | Get-Datacenter

    $uri = "https://$($Server.Name)/folder$(if($Folder){'/'})$($Folder.TrimEnd('/'))?dcPath=$($dc.Name)&dsName=$($ds.Name)"

    foreach($entry in (Invoke-WebRequest -Uri $Uri -Credential $Credential)){

        $entry.Links | %{

            if($_.InnerText -notmatch "^Parent"){

                "[$($ds.Name)] $($Folder)$($_.InnerText.TrimStart('/'))"

            }

            if($_.InnerText -match "/$"){

                Get-DatastoreFiles -Server $Server -DatastoreName $DatastoreName -Credential $Credential -Folder $_.InnerText

            }

        }   

    }

 

}

$vcenter = ''

$vcUser = 'administrator@vsphere.local'

$vcPswd = 'VMware1!'

$datastoreName = 'MyDatastore'

$findFile = '*.iso'


Connect-VIServer $vcenter -User $user -Password $pwd
 

$pswd = ConvertTo-SecureString $vcPswd -AsPlainText -Force

$cred = New-Object System.Management.Automation.PSCredential ($vcUser, $pswd)

 

Get-DatastoreFiles -DatastoreName $datastoreName -Credential $cred | where{$_ -like $findFile}