<#
.SYNOPSIS
    Read the server-side stored content of an Intune platform script via Graph.
.PARAMETER ScriptId
    The Intune platform script ID (GUID).
.NOTES
    Run Connect-MgGraph with DeviceManagementScripts.Read.All first.
.EXAMPLE
    .\Get-StoredScriptContent.ps1 -ScriptId "00000000-0000-0000-0000-000000000000"
#>

param(
    [Parameter(Mandatory)]
    [string]$ScriptId
)

$script = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$ScriptId"

$scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($script["scriptContent"]))
Write-Host $scriptContent
