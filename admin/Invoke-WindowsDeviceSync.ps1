<#
.SYNOPSIS
    Wake the OMA-DM client on all Windows managed devices via Microsoft Graph.
.DESCRIPTION
    Triggers a device sync on every Windows device. This does NOT trigger IME
    PowerShell platform scripts. It refreshes the MDM and OMA-DM workload only.
    Use for policy refresh, not to force a platform script to run.
.NOTES
    Connect-MgGraph with DeviceManagementManagedDevices.Read.All and
    DeviceManagementManagedDevices.PrivilegedOperations.All first.
    Without the privileged scope, syncDevice returns 403 Forbidden.
#>

$devices = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"

foreach ($device in $devices["value"]) {
    Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/syncDevice" `
        -Body "{}" -ContentType "application/json"
    Write-Host "Sync triggered for: $($device.deviceName)"
}
