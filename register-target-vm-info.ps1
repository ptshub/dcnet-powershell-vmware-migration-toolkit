<#
.SYNOPSIS
Registers virtual machines from a JSON file into a vCenter Server, ensuring all required folders exist. Optionally reconnects network adapters after VM registration.

.DESCRIPTION
This script connects to a target vCenter Server, reads VM details from a JSON file, and registers each VM. 
Before registration, it checks if all folders in the VM's original folder path exist in the target vCenter Server's 
inventory and creates them if they do not. It supports filtering VMs based on names and provides options for 
specifying target datastore and network. Optionally, it can reconnect network adapters after VM registration.

.PARAMETER InputFile
Specifies the path to the JSON file containing VM details.

.PARAMETER Target
Specifies the hostname or IP address of the target vCenter Server to register VMs.

.PARAMETER Datastore
Optional. Specifies the target datastore for the registered VMs.

.PARAMETER Network
Optional. Specifies the target network for the registered VMs.

.PARAMETER VMNames
Optional. Specifies a comma-separated list of VM names to filter the registration. Only VMs matching these names 
will be registered.

.EXAMPLE
.\Register-VMs.ps1 -InputFile "C:\VM_Details.json" -Target "vcenter.domain.com"
Registers all VMs from "C:\VM_Details.json" into "vcenter.domain.com".

.EXAMPLE
.\Register-VMs.ps1 -InputFile "C:\VM_Details.json" -Target "vcenter.domain.com" -Datastore "DS1" -Network "VM Network"
Registers all VMs from "C:\VM_Details.json" into "vcenter.domain.com", placing them on datastore "DS1" and network "VM Network".

.EXAMPLE
.\Register-VMs.ps1 -InputFile "C:\VM_Details.json" -Target "vcenter.domain.com" -VMNames "VM1,VM2"
Registers VMs named "VM1" and "VM2" from "C:\VM_Details.json" into "vcenter.domain.com".

.NOTES
Author: Daniel Whicker
Contact: Daniel.Whicker@computacenter.com
Date: June 2024
Version: 1.3
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$Target,

    [string]$Datastore = "",
    [string]$Network = "",
    [string]$VMNames = ""
)

# Import the PowerCLI module
Import-Module VMware.PowerCLI -ErrorAction Stop

# Check if $mycreds is defined, otherwise prompt for vCenterTargetCreds
if (-not $global:mycreds) {
    $TargetCreds = Get-Credential -Message "Enter your target vCenter Server credentials"
} else {
    $TargetCreds = $global:mycreds
}

# Connect to the target vCenter Server using provided credentials
try {
    Connect-VIServer -Server $Target -Credential $TargetCreds -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to target vCenter Server. $_"
    Exit 1
}


# Read the JSON file containing VM details
$vmDetails = Get-Content -Path $InputFile | ConvertFrom-Json

# Filter VMs based on VMNames parameter if provided
if ($VMNames -ne "") {
    $vmNamesArray = $VMNames.Split(",")
    $vmDetails = $vmDetails | Where-Object {$_.Name -in $vmNamesArray}
}

# Get the first VMHost in the cluster to use for registration
$firstVMHost = Get-Cluster | Get-VMHost | Select-Object -First 1

# Loop through each VM detail
foreach ($vm in $vmDetails) {
    # Check if the VM already exists in the target vCenter Server
    if (Get-VM -Name $vm.Name -ErrorAction SilentlyContinue) {
        Write-Warning "VM $($vm.Name) already exists in $($Target). Skipping registration."
        continue
    }

    # Extract folder path from VM details and ensure folders exist
    $folders = $vm.FolderPath -split "\\" | Where-Object { $_ -ne "" }
    $currentFolder = $null

    foreach ($folderName in $folders) {
        if ($currentFolder) {
            $currentFolder = Get-Folder -Name $folderName -Location $currentFolder -ErrorAction SilentlyContinue
        } else {
            $currentFolder = Get-Folder -Name $folderName -ErrorAction SilentlyContinue
        }

        if (-not $currentFolder) {
            Write-Host "Creating folder: $folderName in path: $($vm.FolderPath)"
            if ($currentFolder) {
                $currentFolder = New-Folder -Name $folderName -Location $currentFolder -ErrorAction Stop
            } else {
                $currentFolder = New-Folder -Name $folderName -Location $currentFolder -ErrorAction Stop
            }
        }
    }

    # Register the VM using VMX path and the first VMHost in the cluster
    $vmxPath = $vm.VmxPath
    $vmName = $vm.Name

    try {
        $newVM = New-VM -VMFilePath $vmxPath -VMHost $firstVMHost -Server $Target -Name $vmName -Location $currentFolder
        Write-Host "Registered VM: $($vm.Name) in $($Target) on $($firstVMHost.Name) under folder $($currentFolder.Name)"
    } catch {
        Write-Error "Failed to register VM $($vm.Name). $_"
    }
}

# Disconnect from the target vCenter Server
Disconnect-VIServer -Server $Target -Confirm:$false

Write-Host "VM registration completed from $InputFile"
