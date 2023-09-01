import-module VMware.VimAutomation.Core
import-module VMware.VumAutomation

$VMhost = '10.25.9.239'

write-host "1"

$AsyncJob = Set-VMHost $VMhost -State Maintenance -Confirm:$false -ErrorAction Inquire -whatif

write-host "Maintenance Mode done"


$timeout = new-timespan -seconds 5
$sw = [diagnostics.stopwatch]::StartNew()
While(($AsyncJob.PercentComplete -ne 100) -or ($sw.elapsed -lt $timeout)){

    if($AsyncJob.State -ne 'Success'){

            Write-Progress -Activity "Waiting for $VMhost to Enter Maintenance Mode" -PercentComplete $AsyncJob.PercentComplete
            Start-Sleep -seconds 2
            $AsyncJob = Get-Task -id $AsyncJob.id
        }
}