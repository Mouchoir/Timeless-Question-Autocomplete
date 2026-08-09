<#
.SYNOPSIS
    Mirrors addon\TimelessQuestion into the WoW AddOns folder.

.DESCRIPTION
    Resolves the AddOns path from, in order:
      1. -WowAddOnsPath
      2. $env:TQ_WOW_ADDONS_PATH
      3. scripts\dev.local.ps1 (gitignored, must set $WowAddOnsPath)
    Then robocopy-mirrors the addon folder. Run /reload in game afterwards.
#>
[CmdletBinding()]
param(
    [string]$WowAddOnsPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'addon\TimelessQuestion'

if (-not $WowAddOnsPath) { $WowAddOnsPath = $env:TQ_WOW_ADDONS_PATH }

if (-not $WowAddOnsPath) {
    $localConfig = Join-Path $PSScriptRoot 'dev.local.ps1'
    if (Test-Path $localConfig) { . $localConfig }
}

if (-not $WowAddOnsPath) {
    throw "No AddOns path. Pass -WowAddOnsPath, set TQ_WOW_ADDONS_PATH, or create scripts\dev.local.ps1 with: `$WowAddOnsPath = '<...>\_classic_\Interface\AddOns'"
}

if (-not (Test-Path $WowAddOnsPath)) {
    throw "AddOns path not found: $WowAddOnsPath"
}

$destination = Join-Path $WowAddOnsPath 'TimelessQuestion'
Write-Host "Deploying to $destination"

robocopy $source $destination /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
# robocopy uses 0-7 for success (1 = files copied), 8+ for real failures.
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
$global:LASTEXITCODE = 0

Write-Host 'Done. Type /reload in game.'
