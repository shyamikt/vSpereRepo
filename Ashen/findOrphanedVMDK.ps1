#
# Purpose : List all orphaned vmdk on all datastores in all VC's
# Version: 1.0
# Author  : HJA van Bokhoven

#Main

$OutputFile = ".\OrphanedVMDK.txt"

$vcenter = "icdwtcorevcs02.dcsprod.dcsroot.local"
$user = "DCSUtil\APEREAS1"
$pwd = "asdf@123"

Connect-VIServer $vcenter -User $user -Password $pwd

	 
	$arrUsedDisks = Get-VM | Get-HardDisk | %{$_.filename}
	$arrDS =  Get-Datastore

    #$arrUsedDisks = get-datastore LO3_DSPOD_STD_VNX-8000_CLSO1_29| Get-VM | Get-HardDisk | %{$_.filename}
	#$arrDS = Get-Datastore LO3_DSPOD_STD_VNX-8000_CLSO1_29
    $OutArray = @()

	Foreach ($strDatastore in $arrDS)
	{
	   $strDatastoreName = $strDatastore.name
	   Write-Host $strDatastoreName
	   $ds = Get-Datastore -Name $strDatastoreName | %{Get-View $_.Id}
	   $fileQueryFlags = New-Object VMware.Vim.FileQueryFlags
	   $fileQueryFlags.FileSize = $true
	   $fileQueryFlags.FileType = $true
	   $fileQueryFlags.Modification = $true
	   $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
	   $searchSpec.details = $fileQueryFlags
	   $searchSpec.sortFoldersFirst = $true
	   $dsBrowser = Get-View $ds.browser
	   $rootPath = "["+$ds.summary.Name+"]"
	   $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec)
	   $myCol = @()
	   foreach ($folder in $searchResult)
	   {
	      foreach ($fileResult in $folder.File)
	      {
             $fileresult
             $file = "" | select Name, FullPath			
		     $file.Name = $fileResult.Path
		     $strFilename = $file.Name
		     IF ($strFilename)
		     {
		         IF ($strFilename.Contains(".vmdk")) 
		         {
		             IF (!$strFilename.Contains("-flat.vmdk"))
		             {
		                 IF (!$strFilename.Contains("delta.vmdk"))		  
		                 {
		                        $strCheckfile = "*"+$file.Name+"*"
			                        IF ($arrUsedDisks -Like $strCheckfile)
                                    {}
	                                 ELSE 
			                         {			 
			                        
                                         $details = @{

                                            orphaned_VMDK = $strFilename
                                            Datastore = $strDatastoreName
                                            length = $fileresult.filesize
                                            Disk_Size_GB = $fileresult.filesize/1GB
                                            Last_Write_Time = $fileresult.modification
                                        }

                                        $OutArray += New-Object PSObject -Property $details
			                         }	         
		                 }
		             }		  
		         }
		     }
	      }
	   }       
   }
   $outarray | export-csv "OrphanedVMDK_new.csv"	
