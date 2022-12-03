$poweredon = Get-VM -Server $source | Where-Object PowerState -eq 'PoweredOn'
$poweredoff = Get-VM -Server $source | Where-Object PowerState -eq 'PoweredOff'

