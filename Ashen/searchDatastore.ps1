param($vcenter,$user,$pwd,$datastore)

Connect-VIServer $vcenter -User $user -Password $pwd

$DSpath = Get-Datastore $datastore

Try{
    $file = dir -Recurse -Path $DSpath.DatastoreBrowserPath -Include *asyncUnmapFile* | select Name,DatastoreFullPath,LastWriteTime
}

Catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
}

if($file){
    write-host "File Exist"
}
else{
    write-host "File Does Not Exist"
}