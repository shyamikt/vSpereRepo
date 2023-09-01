$baselinename = "ESXi 6.0 - EP21 - 13635687 (ESXi600-201905001)"

$baseExist = Get-Baseline -name $baselinename


if(!$baseExist){
$patches = Get-Patch -before "14 May 2019" 

$staticBaseline = New-PatchBaseline -Static -Name $baselinename -IncludePatch $patches

}