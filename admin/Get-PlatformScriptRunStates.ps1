<#
.SYNOPSIS
    Read per-device output of an Intune platform script via Microsoft Graph.
.DESCRIPTION
    The Intune portal Device status shows only Succeeded or Failed. This reads the
    full resultMessage per device so you can confirm what the script actually did.
.PARAMETER ScriptId
    The Intune platform script ID (GUID).
.NOTES
    Run Connect-MgGraph with DeviceManagementScripts.Read.All first.
    Invoke-MgGraphRequest returns hashtables. Index with $results["value"].
.EXAMPLE
    .\Get-PlatformScriptRunStates.ps1 -ScriptId "00000000-0000-0000-0000-000000000000"
#>

param(
    [Parameter(Mandatory)]
    [string]$ScriptId
)

$results = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$ScriptId/deviceRunStates"

$results["value"] | ForEach-Object {
    Write-Host "================================"
    Write-Host "RunState: $($_.runState)"
    Write-Host "LastUpdated: $($_.lastStateUpdateDateTime)"
    Write-Host "Output:"
    Write-Host $_.resultMessage
    Write-Host ""
}
