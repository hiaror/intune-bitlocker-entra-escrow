<#
.SYNOPSIS
    Read-only BitLocker survey for Intune platform-script deployment.
.DESCRIPTION
    Reports VolumeStatus, EncryptionPercentage, KeyProtectorCount and protector
    types for the system drive so each device can be routed to an escrow path
    (already encrypted) or an encryption policy (not yet encrypted). Makes no changes.
.NOTES
    Deploy as an Intune platform script.
    Run this script using the logged on credentials: No
    Enforce script signature check: No
    Run script in 64 bit PowerShell Host: Yes
    Version 1.0
#>

$vol = Get-BitLockerVolume -MountPoint C:
$protectors = $vol.KeyProtector

Write-Host "Device: $env:COMPUTERNAME"
Write-Host "VolumeStatus: $($vol.VolumeStatus)"
Write-Host "EncryptionPercentage: $($vol.EncryptionPercentage)"
Write-Host "KeyProtectorCount: $($protectors.Count)"

foreach ($p in $protectors) {
    Write-Host "ProtectorType: $($p.KeyProtectorType) | ID: $($p.KeyProtectorId)"
}

if ($protectors.Count -eq 0) {
    Write-Host "STATUS: No key protectors found. Recovery key escrow not possible yet."
} else {
    Write-Host "STATUS: Key protectors present. Ready for escrow."
}
