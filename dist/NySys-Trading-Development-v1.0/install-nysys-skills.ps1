#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Codex','Claude','Both')][string]$Agent = 'Both',
    [ValidateSet('Project','User')][string]$Scope = 'Project',
    [string]$ProjectPath,
    [string[]]$Name,
    [switch]$DryRun
)
& (Join-Path $PSScriptRoot 'adapters/Manage-Skills.ps1') -Mode 'Install' @PSBoundParameters
