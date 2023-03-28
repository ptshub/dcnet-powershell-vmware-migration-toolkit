# reregister VM's in place
if (!$vcenter_hostname) { $vcenter_hostname = Read-Host -Prompt "vCenter Server Name/IP" }
if (!$creds) { $creds = Get-Credential -Message "vCenter Credentials" }

try {
    if (!$vcenter) { $vcenter = Connect-VIserver -Server $vcenter_hostname -Credential $creds }
} catch {
    Write-Host "Failed to connect to vCenter Server $vcenter_hostname" -ForegroundColor Red
}

$vmlist = Get-VM -Server $vcenter | Where-Object { $_ -Like "rhel-client*" -AND $_ -NotLike "vcsa" } 
$vmxlist = $vmlist | Select-Object Name, FolderID, ResourcePoolID, @{N="VMX";E={$_.Extensiondata.Summary.Config.VmPathName}}

# Power Off VM
$vmlist | Shutdown-VMGuest -Confirm:$false -ErrorAction:Continue

# Ensure Powered Off Before Continuing
foreach ($virt in $vmlist) {
    try {
        $vm = Get-VM -Name $virt.Name
        switch($vm.PowerState){
            'poweredon' {
                Shutdown-VMGuest -VM $vm -Confirm:$false       
                while($vm.PowerState -eq 'PoweredOn'){
                    sleep 5
                    $vm = Get-VM -Name $vm.Name
                }
            } 
            Default {  
                Write-Host "VM '$($vm.Name)' is not powered on!"
            }
        }
    } catch {
        Write-Host "VM '$($vm.Name)' not found!"
    }
}

# UnRegister VM
$vmlist | Remove-VM -DeletePermanently:$false -Confirm:$false

# Add VM
foreach ($vm in $vmxlist) {
  $ResourcePool = Get-ResourcePool -Id $vm.ResourcePoolId
  $Folder = Get-Folder -Id $vm.FolderId
  New-VM -VMFilePath:$vm.VMX -ResourcePool:$ResourcePool -Location:$Folder
}

# Power On VM
$newvmlist = foreach ($vm in $vmxlist) { Get-VM -Name $vm.Name }
$newvmlist | Start-VM
