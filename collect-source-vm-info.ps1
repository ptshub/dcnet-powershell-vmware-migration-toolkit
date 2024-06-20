<#
.SYNOPSIS
Exports details of virtual machines from a vCenter Server to a JSON file, including VM folder paths.

.DESCRIPTION
This script connects to a vCenter Server, retrieves details of virtual machines, and exports the details along with their folder paths to a JSON file. It supports filtering VMs based on power state and specific VM names.

.PARAMETER FileName
Specifies the output file path where the VM details will be exported in JSON format.

.PARAMETER VMNames
Optional. Specifies a comma-separated list of VM names to filter the export. Only VMs matching these names will be included in the output.

.PARAMETER Source
Optional. Specifies the hostname or IP address of the vCenter Server to connect to. If not provided, the script will prompt for it during execution.

.PARAMETER PoweredOn
Switch parameter. If present, only includes VMs that are powered on in the export.

.EXAMPLE
.\Export-VMDetails.ps1 -FileName "C:\VM_Details.json"
Exports details of all VMs from the default vCenter Server to "C:\VM_Details.json".

.EXAMPLE
.\Export-VMDetails.ps1 -FileName "C:\VM_Details.json" -VMNames "VM1,VM2"
Exports details of VMs named "VM1" and "VM2" to "C:\VM_Details.json".

.EXAMPLE
.\Export-VMDetails.ps1 -FileName "C:\VM_Details.json" -Source "vcenter.domain.com"
Connects to the vCenter Server "vcenter.domain.com" and exports details of all VMs to "C:\VM_Details.json".

.EXAMPLE
.\Export-VMDetails.ps1 -FileName "C:\VM_Details.json" -PoweredOn
Exports details of powered on VMs from the default vCenter Server to "C:\VM_Details.json".

.NOTES
Author: Daniel Whicker
Contact: Daniel.Whicker@computacenter.com
Date: June 2024
Version: 1.3
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$FileName,

    [string]$VMNames = "",
    [string]$Source = "",
    [switch]$PoweredOn
)

# Function to retrieve VM details and construct custom object
function Get-VMCustomObject {
    param ($vm)
    
    $vmGuest = Get-VMGuest -VM $vm
    $datastores = (Get-Datastore -VM $vm).Name -join ", "
    
    # Get the VM folder path, handling cases where it might be null
    $vmFolder = Get-View $vm.ExtensionData.Parent
    if ($vmFolder) {
        $folderPath = Get-FolderPath $vmFolder
    } else {
        $folderPath = "Unknown"
    }
    
    # Get all hard disks information
    $hardDisks = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_ -is [VMware.Vim.VirtualDisk] } | ForEach-Object {
        [PSCustomObject]@{
            Label = $_.DeviceInfo.Label
            CapacityGB = [math]::Round($_.CapacityInKB / 1MB, 2)
            ThinProvisioned = $_.Backing.ThinProvisioned
            Datastore = (Get-Datastore -Id $_.Backing.Datastore).Name
            VMDKPath = $_.Backing.FileName
        }
    }
    
    # Get all network adapters information
    $networkAdapters = Get-NetworkAdapter -VM $vm | ForEach-Object {
        if ($_.NetworkName) {
            $portGroup = $_.NetworkName
        } else {
            $portGroup = "Unknown"
        }
        [PSCustomObject]@{
            Label = $_.Name
            NetworkName = $_.NetworkName
            PortGroup = $portGroup
            MacAddress = $_.MacAddress
            IP = ($vmGuest.Nics | Where-Object { $_.NetworkName -eq $_.NetworkName }).IpAddress -join ", "
        }
    }
    
    [PSCustomObject]@{
        Name = $vm.Name
        VMHost = $vm.VMHost.Name
        NumCPU = $vm.NumCPU
        MemoryGB = $vm.MemoryGB
        Version = $vm.Version
        IP = ($vmGuest.IPAddress -join ", ")
        Datastore = $datastores
        VmxPath = $vm.ExtensionData.Config.Files.VmPathName
        FolderPath = $folderPath
        HardDisks = $hardDisks
        NetworkAdapters = $networkAdapters
    }
}

# Function to get folder path recursively
function Get-FolderPath {
    param ($Folder)
    
    $folderPath = $Folder.Name
    while ($Folder.Parent -and $Folder.Parent.Type -eq "Folder") {
        $Folder = Get-View $Folder.Parent
        $folderPath = $Folder.Name + "\" + $folderPath
    }
    
    return $folderPath
}

# Import the PowerCLI module
Import-Module VMware.PowerCLI -ErrorAction Stop

# Ask for vCenter Server hostname if not provided via the -Source parameter
if ($Source -eq "") {
    $Source = Read-Host -Prompt "Enter vCenter Server hostname or IP address"
}

# Ask for vCenter Server credentials if $mycreds is not already configured
if (-not $global:mycreds) {
    $global:mycreds = Get-Credential -Message "Enter your vCenter Server credentials"
}

# Connect to vCenter Server using provided credentials
try {
    Connect-VIServer -Server $Source -Credential $global:mycreds -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to vCenter Server. $_"
    Exit 1
}

# Initialize the variable to store VM details
$vmDetails = @()

# Check if VMNames parameter is provided
if ($VMNames -ne "") {
    # Convert comma-separated VM names to an array
    $vmNameArray = $VMNames -split ","
    
    # Get details of each specified virtual machine
    foreach ($vmName in $vmNameArray) {
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            $vmDetails += Get-VMCustomObject $vm
        } else {
            Write-Warning "VM '$vmName' not found."
        }
    }
} else {
    # Get details of all virtual machines
    $vmList = Get-VM
    if ($PoweredOn) {
        $vmList = $vmList | Where-Object {$_.PowerState -eq "PoweredOn"}
    }
    
    $vmList | ForEach-Object {
        $vmDetails += Get-VMCustomObject $_
    }
}

# Export details to a JSON file with increased depth
$vmDetails | ConvertTo-Json -Depth 4 | Out-File -FilePath $FileName -Force

# Disconnect from vCenter Server
Disconnect-VIServer -Server $Source -Confirm:$false

Write-Host "Virtual machine details exported to $FileName"
