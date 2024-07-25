$baseurl = "https://www.examtopics.com/discussions/nutanix/view/"
$pagestart = "128899"
$pageend = "144167"

foreach ($pagenu in $pagestart..$pageend){
    $fullurl = "$($baseurl)$($pagenu)-exam"
    
    $page = Invoke-WebRequest -Uri "$fullurl"
    if($page.ParsedHtml.title -match "NCP-US v6.5"){

        $result = [PSCustomObject]@{
        'url' = $fullurl
        'title' = $page.ParsedHtml.title

        }
    $result | Export-Csv C:\iShya\examtopics\NUSApages.csv -Append -NoTypeInformation 
    }
}

