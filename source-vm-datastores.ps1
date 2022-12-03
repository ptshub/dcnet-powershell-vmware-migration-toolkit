# List the datastore names for each powered on VM

get-vm -server $source | Where-Object PowerState -eq "PoweredOn" | Select-Object Name,@{N="Datastore";E={[string]::Join(',',(Get-Datastore -Id $_.DatastoreIdList | Select-Object -ExpandProperty Name))}} | Format-Table -AutoSize