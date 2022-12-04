$vmxpathlist = import-csv -path .\source.vmx.paths.csv

foreach ($vm in $vmxpathlist) {
    New-VM -VMFilePath $vm.VMX
}