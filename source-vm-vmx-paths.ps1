$vmxlist = Get-VM -Server $source | Where-Object PowerState -eq PoweredOn | Select Name, @{N="VMX";E={$_.Extensiondata.Summary.Config.VmPathName}}

$vmxlist | Export-Csv -Path source.vmx.paths.csv