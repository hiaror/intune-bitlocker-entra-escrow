# Intune BitLocker to Entra ID Escrow (Intune Platform Scripts)

**Overview** — PowerShell toolset for escrowing existing BitLocker recovery keys to Microsoft Entra ID at fleet scale using Intune platform scripts, with a configuration-policy fallback for devices that are not yet encrypted. Validated across three Windows 11 virtual machines in a Microsoft 365 lab tenant.

**Why This Exists** — When you remove a third-party disk encryption agent such as Sophos from a Windows fleet, the BitLocker encryption it provisioned often stays active while the recovery key is never escrowed to Entra ID. The result is fully encrypted devices whose recovery keys exist nowhere central. `Get-BitLockerVolume` returns `VolumeStatus FullyEncrypted`, `EncryptionPercentage 100`, and `KeyProtector` empty. `BackupToAAD-BitLockerKeyProtector` has nothing to back up because no `RecoveryPassword` protector exists. The fix adds a `RecoveryPassword` protector first, then escrows it. Backing up keys one device at a time through the Entra portal works but does not scale to a fleet.

**Key Capabilities** — Two-path fleet design (survey-then-act); idempotent escrow script safe to re-run; read-only survey classifies every device before any change; Path 1 adds a `RecoveryPassword` protector if missing then escrows to Entra ID; Path 2 handled by a native Endpoint Security BitLocker configuration policy for unencrypted devices; admin-side Graph scripts for monitoring run states and triggering device sync; all scripts run in SYSTEM context via Intune platform script deployment.

**Repository Structure**
```
.
├── scripts/
│   ├── Diag-BitLocker-KeyProtector-Status.ps1
│   └── Escrow-BitLocker-RecoveryKey-To-EntraID.ps1
├── admin/
│   ├── Get-PlatformScriptRunStates.ps1
│   ├── Get-StoredScriptContent.ps1
│   └── Invoke-WindowsDeviceSync.ps1
├── sample-data/
│   └── survey-output.sample.txt
├── LICENSE
└── README.md
```

**Prerequisites** — PowerShell 5.1 or 7.x; Microsoft Graph PowerShell SDK on the admin workstation; Microsoft Intune with Entra ID; Windows 10 or Windows 11 devices enrolled in Intune; TPM 2.0 for silent encryption on the Path 2 policy; each device must have an Entra device object to be an escrow target.

**Required Graph Scopes** — `DeviceManagementScripts.Read.All`, `DeviceManagementManagedDevices.Read.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementConfiguration.Read.All`.

**Platform script settings** for both device scripts: Run this script using the logged on credentials: No. Enforce script signature check: No. Run script in 64 bit PowerShell Host: Yes. The 64-bit host setting is not optional. BitLocker cmdlets return missing or unreliable data in the 32-bit host on 64-bit Windows.

**Usage** — Deploy `Diag-BitLocker-KeyProtector-Status.ps1` first assigned to All devices to classify the fleet. Read results via `Get-PlatformScriptRunStates.ps1` passing the survey script ID. Deploy `Escrow-BitLocker-RecoveryKey-To-EntraID.ps1` to All devices or a staged security group for Path 1 devices. Monitor run states via `Get-PlatformScriptRunStates.ps1`. To re-run a platform script after it has already executed, add a version comment to the top of the script and save. This changes the content hash and forces re-evaluation. `Invoke-WindowsDeviceSync.ps1` wakes the OMA-DM client but does NOT trigger platform scripts. To force immediate evaluation during testing, restart the `IntuneManagementExtension` service on the device. After restart expect a 237-second delay before the PowerShell workload fires.

**Critical timing note** — The Intune portal Sync button and Graph `syncDevice` do not trigger IME PowerShell platform scripts. They wake only the MDM OMA-DM client. Platform scripts run on the IME internal timer of roughly eight hours. The widely quoted sixty-minute figure is the Win32 app workload, which is a separate mechanism. Session-change events such as user logon, logoff, or unlock trigger immediate evaluation. Plan for up to eight hours on idle devices.

**Reporting** — `Diag-BitLocker-KeyProtector-Status.ps1` writes per-device output to Intune `resultMessage` covering Device, VolumeStatus, EncryptionPercentage, KeyProtectorCount, and STATUS. The Intune Device status tab shows only Succeeded or Failed. Use `Get-PlatformScriptRunStates.ps1` to read the full `resultMessage` per device. The GUI result is not proof of outcome. Validate via `deviceRunStates` or the device `AgentExecutor.log` at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log`.

**Safety Notes** — Device-side scripts run in SYSTEM context and make no network calls outside the local BitLocker module and the Entra escrow endpoint. The escrow script adds a `RecoveryPassword` protector and escrows it silently. The recovery password is never written to script output, only the `KeyProtectorId`. Admin-side scripts are read-only against Intune and Entra ID except for `syncDevice` which triggers a device check-in only. Recovery keys retrieved from Entra are sensitive and access should be restricted to IT staff via the Entra device BitLocker keys blade.

**Disclaimer** — Provided as-is for reference and learning purposes. Sample data and identifiers are sanitized. Test in a lab environment before production deployment.
