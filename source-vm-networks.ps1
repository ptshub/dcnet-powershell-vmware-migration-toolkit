$vmlist = get-vm -server $source -name "rhel-client01" | where-object PowerState -eq "PoweredOn"

$adapters = $vmlist | Get-NetworkAdapter # | Select-Object Parent,Name,NetworkName

$adapters
