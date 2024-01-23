#Connect-VIServer vsphereqa

function Wait-mTaskvMotions {

    [CmdletBinding()]

    Param(

      [int] $vMotionLimit=1,

      [int] $DelayMinutes=1

    )

    $NumvMotionTasks = (Get-Task | ? { ($_.PercentComplete -ne 100) -and ($_.Description -match 'Apply Storage DRS recommendations|Migrate virtual machine|Relocate virtual machine')} | Measure-Object).Count

    While ( $NumvMotionTasks -ge $vMotionLimit ) {

        Write-Verbose "$(Get-Date)- Waiting $($DelayMinutes) minute(s) before checking again."

        Start-Sleep ($DelayMinutes * 60)

        $NumvMotionTasks = (Get-Task | ? { ($_.PercentComplete -ne 100) -and ($_.Description -match 'Apply Storage DRS recommendations|Migrate virtual machine|Relocate virtual machine')} | Measure-Object).Count

    }

   

    Write-Verbose "$(Get-Date)- Proceeding."

} # end function

$filepath = ".\svmotion_bulk_thik2thin\svmotionlist.csv"

$csvobj = import-csv $filepath

foreach ($row in $csvobj) {

     $vmobj = get-vm $row.vmname

     $ds = get-datastore $row.destds

     $vmobj | Get-Snapshot | %{Remove-Snapshot $_ -Confirm:$false }

     $vmobj | move-vm -datastore $ds -DiskStorageFormat Thin -confirm:$false -runasync

     Wait-mTaskvMotions -vMotionLimit 2 # This will keep going through the foreach loop until 4 tasks are registered (vMotion or Storage vMotion), waits 5 minutes between checks.  Will only continue to process loop when vMotion tasks are less than 4.

}