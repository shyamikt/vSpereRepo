# Install-All  <version> <ucs> <ucscredentials> <imageDir> <ccocredentials> 

param(
    [parameter(Mandatory=${true})][string]${version},
    [parameter(Mandatory=${true})][string]${ucs},
    [parameter(Mandatory=${true})][string]${imageDir}
)

	
Try
{
	${Error}.Clear()

	${versionSplit} = ${version}.Split("()")
	${versionBundle} = ${versionSplit}[0] + "." + ${versionSplit}[1]
	
	${aSeriesBundle} = "ucs-k9-bundle-infra." + ${versionBundle} + ".A.bin"
	${bSeriesBundle} = "ucs-k9-bundle-b-series." + ${versionBundle} + ".B.bin"
	${cSeriesBundle} = "ucs-k9-bundle-c-series." + ${versionBundle} + ".C.bin"
		
	${bundle} = @(${aSeriesBundle},${bSeriesBundle},${cSeriesBundle})
	${ccoImageList} = @()
	
	foreach(${eachBundle} in ${bundle})
	{
		${fileName} = ${imagedir} +  "\" + ${eachBundle}
		if( test-path -Path ${fileName})
		{
		 	Write-Host "Image File : ${eachBundle} already exist in local directory."
		}
		else
		{
			${ccoImageList} += ${eachBundle}
		}
	}
	
	if( ${ccoImageList} -ne ${null})
	{
		Write-Host  "Enter CCO Credential"
		${ccoCred} = Get-Credential
		foreach(${imageBundle} in ${ccoImageList})
		{
			[array]${ccoImage} += Get-UcsCcoImageList -Credential ${ccoCred} | where { $_.ImageName -match ${imageBundle}} 
		}
		if(${ccoImage} -eq ${null})
		{
			Write-Host "Image File does not exist in repository"
			exit
		}
		Write-Host  "Downloading image on local machine"
		${ccoImage} | Get-UcsCcoImage -Path ${imageDir}
	}
	    
	# Login into UCS
	Write-Host  "Enter UCS Credential"
	${ucsCred} = Get-Credential
	${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred}
	    
	if (${Error})
	{
	    Write-Host ${Error}
	    exit
	}

	foreach (${image} in ${bundle})
	{
 	    ${firmwarePackage} = Get-UcsFirmwarePackage -Name ${image}

		${deleted} = $false
		if (${firmwarePackage})
		{
			${deleted} = ${firmwarePackage} | Get-UcsFirmwareDistImage | ? { $_.ImageDeleted -ne ""}
		}
	      
	    if (${deleted} -or !${firmwarePackage})
	    {
	        # Image does not exist on fi, upload
			$fileName = ${imageDir} +  "\" + ${image}
            Write-Host  "Uploading image : ${image} on FI"
			Send-UcsFirmware -LiteralPath $fileName | Watch-Ucs -Property TransferState -SuccessValue downloaded -PollSec 30 -TimeoutSec 600
	    }
	}
	      
	# Need to convert version to avoid cannot validate argument on parameter 'Name'. Ex 1.4(3i) should be 1.4-3i
	[array]${versionName} = ${version}.Split("()")
	${versionPack} = ${versionName}[0] + "-" + ${versionName}[1]
	        
	${bSeriesVersion} = ${version} + "B"
	${cSeriesVersion} = ${version} + "C"
	[array]${imageNames} = (Get-UcsFirmwarePackage | ? { $_.Version -like ${bSeriesVersion} -or $_.Version -like ${cSeriesVersion} } | Get-UcsFirmwareDistImage | select -ExpandProperty Name)
	[array]${images} = (Get-UcsFirmwareInstallable | ? { $_.Model -ne "MGMTEXT" -and $_.Model -ne "CAPCATALOG" -and ${imageNames} -contains $_.Name })

	# Check if host-pack (with the version as name) exist
	if (Get-UcsFirmwareComputeHostPack -Name ${versionPack})
	{
	    Write-Host "host-pack already exist"
	}
	else # Create a host-pack
	{
	    Write-Host "Creating host-pack ${versionPack}"
		Start-UcsTransaction
	    ${firmwareComputeHostPack} = Add-UcsFirmwareComputeHostPack -Name ${versionPack}
	    ${images} | ? { $_.Type -ne "blade-controller" -and $_.Type -ne "CIMC" } | % { ${firmwareComputeHostPack} | Add-UcsFirmwarePackItem -HwModel $_.Model -HwVendor $_.Vendor -Type $_.Type -Version $_.Version }
		Complete-UcsTransaction
	}
	      
	# Check if mgmt-pack (with the version as name) exist
	if (Get-UcsFirmwareComputeMgmtPack -Name ${versionPack})
	{
	    Write-Host "mgmt-pack already exist"
	}
	else # Create a mgmt-pack
	{
	    Write-Host "Creating mgmt-pack ${versionPack}"
		Start-UcsTransaction
	    ${firmwareComputeMgmtPack} = Add-UcsFirmwareComputeMgmtPack -Name ${versionPack}
	    ${images} | ? { $_.Type -eq "blade-controller" -or $_.Type -eq "CIMC" } | % { ${firmwareComputeMgmtPack} | Add-UcsFirmwarePackItem -HwModel $_.Model -HwVendor $_.Vendor -Type $_.Type -Version $_.Version }
		Complete-UcsTransaction
	}

	        
	# Activate UCSM
	${firmwareRunningUcsm} = Get-UcsMgmtController -Subject system | Get-UcsFirmwareRunning
	if (${firmwareRunningUcsm}.version -eq ${version})
	{
	    Write-Host "UCSM already at version ${version}"
	}
	else
	{
	    Write-Host "Activating UCSM version ${version}. This will require a re-login."
	    Get-UcsMgmtController -Subject system | Get-UcsFirmwareBootDefinition | Get-UcsFirmwareBootUnit | Set-UcsFirmwareBootUnit -Version ${version} -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes
	    Write-Host  "Please wait while system reboots, it may take 5-10 minutes"
		Try
		{
	    	Disconnect-Ucs
		}
		Catch
		{
			Write-Host  "Error disconnecting from UCS"
		}
	    Write-Host  "Sleeping for 5 minutes ..."
	    Start-Sleep -s 240
	    do
	    {
	        Start-Sleep -s 60
	        Write-Host  "Retrying login ..."
			Try
			{
	        	${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred}
			}
			Catch
			{
				Write-Host  "Error connecting to UCS"
			}
	    } while (${myCon} -eq ${null})
	}

	# Update/Activate IOM
	${iomController} = Get-UcsChassis | Get-UcsIom | Get-UcsMgmtController -Subject iocard 
	${iomUpdateList} = @()
	${count} = 0
	foreach (${iom} in ${iomController})
	{
		${count}++
	    ${firmwareRunning} = ${iom} | Get-UcsFirmwareRunning -Deployment system
	    if (${firmwareRunning}.version -eq ${version})
	    {
	        Write-Host "IOM ${count} already at version ${version}"
	    }
	    else
	    { 
	        Write-Host "Updating IOM ${count} to version ${version}"
			${iomUpdateList} += ${iom}
		}
	}

	${iomUpdateList} |  Get-UcsFirmwareUpdatable | Set-UcsFirmwareUpdatable -Version ${version} -AdminState triggered 

	do
	{
		${readyCount} = ${iomUpdateList} |  Get-UcsFirmwareUpdatable -OperState ready | measure 
		if (${readyCount}.count -eq ${iomUpdateList}.count)
		{
			break
		}
		Start-Sleep -s 120
	} while (${readyCount}.count -ne ${iomUpdateList}.count)

	${iomUpdateList} | Get-UcsFirmwareBootDefinition | Get-UcsFirmwareBootUnit | Set-UcsFirmwareBootUnit -Version ${version} -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate no | Watch-Ucs -Property OperState -SuccessValue pending-next-boot -PollSec 30 -TimeoutSec 600
	
	# Version to upgrade in FI
	${aSeriesVersion} = ${version} + "A"
	${switchVersion} = Get-UcsFirmwarePackage -Version ${aSeriesVersion} | Get-UcsFirmwareDistImage | % { Get-UcsFirmwareInstallable -Name $_.Name -Type switch-software }

    if (Get-UcsStatus | ? { $_.HaConfiguration -eq "cluster" })
	{
		# Activate secondary FI
		${secFiController} = Get-UcsNetworkElement -Id (Get-UcsMgmtEntity -Leadership subordinate).Id | Get-UcsMgmtController 
		${secFiActivated} = ${secFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes

		# Wait for secondary to complete re-boot & check for activate status .. 8 .. 12 minutes
		if(${secFiActivated} -ne ${null})
		{
			Write-Host  "Please wait while secondary FI activates, it may take 8-10 minutes"
			Write-Host  "Sleeping for 8 minutes ..."
			Start-Sleep -s 480
			do
			{
				${readyCount} = ${secFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit |  ?  { $_.OperState -eq "ready" }  | measure 
				if (${readyCount}.count -eq ${secFiActivated}.count)
				{
					break
				}
				# Sleep for 2 minutes
				Start-Sleep -s 120
			} while (${readyCount}.count -ne ${secFiActivated}.count)
		}
		else
		{
			 Write-Host "Secondary FI already at version" ${switchVersion}[0].version
		}
			  
		# Activate primary FI
		${priFiController} = Get-UcsNetworkElement -Id (Get-UcsMgmtEntity -Leadership primary).Id | Get-UcsMgmtController 
		${priFiActivated} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes
	}
	else
	{
		${priFiController} = Get-UcsMgmtController -Subject switch
		${priFiActivated} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit | ? { $_.Version -ne  ${switchVersion}[0].version } | Set-UcsFirmwareBootUnit -Version ${switchVersion}[0].version -AdminState triggered -IgnoreCompCheck yes -ResetOnActivate yes
	}
	
	if (${priFiActivated} -ne ${null})
	{
	    Write-Host  "Activating primary FI ..."
		Write-Host  "Please wait while system reboots, it may take 10-15 minutes"
		Try
		{
	    	Disconnect-Ucs
		}
		Catch
		{
			Write-Host  "Error disconnecting from UCS"
		}
		Write-Host  "Sleeping for 15 minutes ..."
		Start-Sleep -s 840
		do
		{
		    Start-Sleep -s 60
		    Write-Host  "Retrying login ..."
		    Try
			{
	        	${myCon} = Connect-Ucs -Name ${ucs} -Credential ${ucsCred}
			}
			Catch
			{
				Write-Host  "Error connecting to UCS"
			}
		} while (${myCon} -eq ${null})
	}

	# Check if primary FI activated successfully
	if(${priFiActivated} -ne ${null})
	{
		do
		{
		    if (Get-UcsStatus | ? { $_.HaConfiguration -eq "cluster" })
			{
				${priFiController} = Get-UcsNetworkElement -Id (Get-UcsMgmtEntity -Leadership primary).Id | Get-UcsMgmtController 
			}
			else
			{
				${priFiController} = Get-UcsMgmtController -Subject switch
			}
			${readyCount} = ${priFiController} | Get-UcsFirmwareBootDefinition |  Get-UcsFirmwareBootUnit  |  ?  { $_.OperState -eq "ready" }  | measure 
			if (${readyCount}.count -eq ${priFiActivated}.count)
			{
				break
			}
		} while (${readyCount}.count -ne ${priFiActivated}.count)
	}
	else
	{
		 Write-Host "Primary FI already at version" ${switchVersion}[0].version
	}
			  

	# Update host & management pack name for all updating-template service profiles
	Get-UcsServiceProfile -Type updating-template | ? { $_.HostFwPolicyName -ne ${versionPack} -or $_.MgmtFwPolicyName -ne ${versionPack} } | Set-UcsServiceProfile -HostFwPolicyName ${versionPack} -MgmtFwPolicyName ${versionPack}

	# Update host & management pack name for all instance and initial-template service profiles
	Get-UcsServiceProfile | ? { $_.Type -ne "updating-template" } | ? { $_.HostFwPolicyName -ne ${versionPack} -or $_.MgmtFwPolicyName -ne ${versionPack} } | Set-UcsServiceProfile -HostFwPolicyName ${versionPack} -MgmtFwPolicyName ${versionPack}

	#Disconnect from UCS
	Write-Host "Install-All executed successfully. Disconnecting from UCS"
	Disconnect-Ucs
}
Catch
{
	Write-Host ${Error}
	exit
}
