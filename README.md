# intune-bitlocker-entra-escrow

## Overview
PowerShell toolset for escrowing existing BitLocker recovery keys to Microsoft Entra ID at fleet scale using Intune platform scripts, with a configuration-policy fallback for devices that are not yet encrypted. Validated across three Windows 11 virtual machines in a Microsoft 365 lab tenant.

## Why This Exists

When you remove a third-party disk encryption agent such as Sophos from a Windows fleet, the BitLocker encryption it provisioned often stays active while the recovery key is never escrowed to Entra ID. The result is fully encrypted devices whose recovery keys exist nowhere central.

The diagnostic state on an affected device:
- `Get-BitLockerVolume` returns `VolumeStatus: FullyEncrypted`, `EncryptionPercentage: 100`, and `KeyProtector: {}`
- `BackupToAAD-BitLockerKeyProtector` has nothing to back up because no `RecoveryPassword` protector exists
- Backing up keys one device at a time through the Entra portal works but does not scale to a fleet

The fix adds a `RecoveryPassword` protector first, then escrows it to Entra ID via an Intune platform script assigned to all devices.

## Key Capabilities
- Two-path fleet design decided per device by a read-only survey before any change is made
- Idempotent escrow script safe to re-run on already-escrowed devices
- Path 1 adds a `RecoveryPassword` protector if missing then escrows every `RecoveryPassword` protector to Entra ID
- Path 2 handled by a native Endpoint Security BitLocker configuration policy for devices not yet encrypted
- Admin-side Graph scripts for monitoring run states and triggering device sync
- All device scripts run in SYSTEM context via Intune platform script deployment

## Repository Structure

```
.
├── scripts/
│   ├── Diag-BitLocker-KeyProtector-Status.ps1
│   ├── Escrow-BitLocker-RecoveryKey-To-EntraID.ps1
│   ├── Get-PlatformScriptRunStates.ps1
│   ├── Get-StoredScriptContent.ps1
│   └── Invoke-WindowsDeviceSync.ps1
├── sample-data/
│   └── survey-output.sample.txt
└── README.md
```

## Prerequisites
- PowerShell 5.1 or 7.x
- `Microsoft.Graph` PowerShell SDK installed on the admin workstation
- Microsoft Intune with Entra ID
- Windows 10 or Windows 11 devices enrolled in Intune
- TPM 2.0 for silent encryption on the Path 2 policy
- Each device must have a Microsoft Entra device object to be an escrow target

## Required Graph Scopes
- `DeviceManagementScripts.Read.All` (read script run states and stored content)
- `DeviceManagementManagedDevices.Read.All` (list managed devices)
- `DeviceManagementManagedDevices.PrivilegedOperations.All` (syncDevice action, without this `syncDevice` returns 403 Forbidden)
- `DeviceManagementConfiguration.Read.All` (policy read)

Connect with all required scopes in a single `Connect-MgGraph` call after `Disconnect-MgGraph`. A bare reconnect reuses the cached MSAL token and will not pick up newly added scopes.

## Platform Script Settings
Both device-side scripts must be deployed with these Intune settings:
- Run this script using the logged on credentials: **No**
- Enforce script signature check: **No**
- Run script in 64 bit PowerShell Host: **Yes**

The 64-bit host setting is not optional. `Get-BitLockerVolume` returns missing or unreliable data in the 32-bit PowerShell host on 64-bit Windows.

## Usage Examples

### Step 1: Deploy the Survey Script
Deploy `Diag-BitLocker-KeyProtector-Status.ps1` assigned to All devices to classify the fleet. Devices reporting `KeyProtectorCount: 0` go to Path 1.

### Step 2: Read Survey Results via Graph
```powershell
.\Get-PlatformScriptRunStates.ps1 -ScriptId "your-survey-script-id"
```

### Step 3: Deploy the Escrow Script
Deploy `Escrow-BitLocker-RecoveryKey-To-EntraID.ps1` to All devices or a staged security group for Path 1 devices.

### Step 4: Monitor Escrow Results via Graph
```powershell
.\Get-PlatformScriptRunStates.ps1 -ScriptId "your-escrow-script-id"
```

### Force Immediate Evaluation During Testing
To bypass the 8-hour IME timer during testing, restart the IME service as a local administrator:
```powershell
Restart-Service IntuneManagementExtension -Force
```
After restart, expect a 237-second delay before the PowerShell workload fires.

### Re-run a Script That Has Already Executed
Add or update a version comment at the top of the script file and save. This changes the content hash and forces re-evaluation on the next IME cycle. The script ID does not change.

## Critical Timing Note

The Intune portal Sync button and the Graph `syncDevice` action do not trigger IME PowerShell platform scripts. They wake only the Windows MDM OMA-DM client. The IME evaluates PowerShell platform scripts on its own internal timer of roughly eight hours. The widely quoted sixty-minute figure is the Win32 app workload, which is a different mechanism entirely.

What actually triggers a platform script:
- User logon, logoff, or unlock (immediate evaluation)
- IME service restart (237-second delay then fires)
- Reboot
- Company Portal sync

Plan for up to eight hours on idle devices. Actively used machines run within minutes because logon events trigger evaluation.

## Reporting
`Diag-BitLocker-KeyProtector-Status.ps1` writes per-device output to the Intune `resultMessage` field:
- Device name
- VolumeStatus
- EncryptionPercentage
- KeyProtectorCount
- Protector type and ID per protector
- STATUS (no protectors found / ready for escrow)

The Intune Device status tab shows only Succeeded or Failed and is not proof of outcome. Use `Get-PlatformScriptRunStates.ps1` to read the full `resultMessage` per device via Graph. Confirm in Entra under Devices > All devices > select device > BitLocker keys.

## Safety Notes
- Device-side scripts run in SYSTEM context and make no network calls outside the local BitLocker module and the Entra escrow endpoint
- The recovery password is never written to script output, only the `KeyProtectorId` is logged
- Admin-side scripts are read-only against Intune and Entra ID except for `Invoke-WindowsDeviceSync.ps1` which triggers a device check-in only
- Recovery keys retrieved from Entra are sensitive, restrict access to the BitLocker keys blade to IT staff only
- Test in a lab environment before production deployment

## Disclaimer
Provided as-is for reference and learning purposes. Sample data and identifiers are sanitized. Verify all steps on a test device before production rollout.

## Blog Post

A full write-up of the two-path approach, the IME timing behaviour, and the Graph scope gotchas is at [AroraMSP: BitLocker recovery keys missing from Entra ID after removing a third-party agent](https://aroramsp.com/blog/intune-bitlocker-entra-escrow).
