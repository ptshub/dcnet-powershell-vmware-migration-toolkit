$global:source_vcenter = "ht-vcenter67dc.healthtexas.local"
$global:target_vcenter = "gs-dc-vc-01.healthtexas.local"
$default_username = "Administrator@vsphere.local"

if (!$source_vcenter_creds) { $source_vcenter_creds = Get-Credential -Message "Source vCenter Creds" -UserName $default_username }
if (!$target_vcenter_creds) { $target_vcenter_creds = Get-Credential -Message "Target vCenter Creds" -UserName $default_username }

try {
    $global:source = Connect-VIserver -Server $source_vcenter -Credential $source_vcenter_creds
} catch {
    Write-Host "Failed to connect to vCenter Server $source_vcenter" -ForegroundColor Red
}
try {
    $global:target = Connect-VIserver -Server $target_vcenter -Credential $target_vcenter_creds
} catch {
    Write-Host "Failed to connect to vCenter Server $target_vcenter" -ForegroundColor Red
}

$source
$target