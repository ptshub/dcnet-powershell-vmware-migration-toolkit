$vmlist = get-vm -server $source | where-object PowerState -eq "PoweredOn"

$adapters = $vmlist | Get-NetworkAdapter # | Select-Object Parent,Name,NetworkName

$adapters | Export-Csv -Path south.vmnetworks.csv
