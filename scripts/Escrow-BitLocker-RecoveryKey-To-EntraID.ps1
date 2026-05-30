<#
.SYNOPSIS
    Add a BitLocker RecoveryPassword protector if missing, then escrow to Entra ID.
.DESCRIPTION
    For devices that are already BitLocker-encrypted but have no RecoveryPassword
    protector escrowed to Entra ID, which is common after removing a third-party
    encryption agent. Ensures a RecoveryPassword protector exists, then escrows every
    RecoveryPassword protector to Microsoft Entra ID. Idempotent and safe to re-run.
.NOTES
    Deploy as an Intune platform script.
    Run this script using the logged on credentials: No
    Enforce script signature check: No
    Run script in 64 bit PowerShell Host: Yes
    Requires the device to have a Microsoft Entra device object.
    Version 1.0
#>

try {
    $drive = $env:SystemDrive

    $vol = Get-BitLockerVolume -MountPoint $drive
    $existing = $vol.KeyProtector |
        Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

    if ($existing) {
        Write-Host 'Recovery password protector already exists. Proceeding to escrow.'
    } else {
        Write-Host 'No recovery password protector found. Adding one now.'
        Add-BitLockerKeyProtector -MountPoint $drive -RecoveryPasswordProtector
        Write-Host 'Recovery password protector added successfully.'
    }

    $vol = Get-BitLockerVolume -MountPoint $drive
    $protectors = $vol.KeyProtector |
        Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

    foreach ($protector in $protectors) {
        BackupToAAD-BitLockerKeyProtector -MountPoint $drive `
            -KeyProtectorId $protector.KeyProtectorId
        Write-Host "Recovery key escrowed to Entra ID. KeyProtectorId: $($protector.KeyProtectorId)"
    }

    Write-Host "STATUS: Completed successfully on $env:COMPUTERNAME"

} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
}
