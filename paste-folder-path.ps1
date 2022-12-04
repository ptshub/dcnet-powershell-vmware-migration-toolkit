Import-Csv -Path '.\folders.csv' -UseCulture |
Sort-Object -Property {(Select-String -InputObject $_.Path -Pattern '/+' -AllMatches).Matches.Count} | %{
$dcName,$rest = $_.Path.Split('\')
$location = Get-Datacenter -Name $dcName | Get-Folder -Name 'vm'
if($rest.count -gt 1){
    $rest[0..($rest.Count -2)] | %{
        $location = Get-Inventory -Name $_ -Location $location -NoRecursion
    }
    $newFolder = $rest[-1]
}
else{
    $newFolder = $rest
}
New-Folder -Name $newFolder -Location $location
}