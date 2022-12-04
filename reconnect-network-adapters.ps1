$sourcelist = import-csv .\source.vmx.paths.csv

foreach ($virt in $sourcelist) {
    $vm = get-vm -server $target -name $virt.name
    foreach ($adapter in ($vm | Get-NetworkAdapter -Server $target)) {
        $adapter | Set-NetworkAdapter -Server $target -PortGroup $adapter.NetworkName 
    }
}
