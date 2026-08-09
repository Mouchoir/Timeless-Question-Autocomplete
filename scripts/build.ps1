<#
.SYNOPSIS
    Packages addon\TimelessQuestion into dist\TimelessQuestion.zip.

.DESCRIPTION
    The zip contains a single top-level TimelessQuestion\ folder, which is what
    both CurseForge and a manual drop into Interface\AddOns expect.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'addon\TimelessQuestion'
$dist = Join-Path $repoRoot 'dist'
$zip = Join-Path $dist 'TimelessQuestion.zip'

if (-not (Test-Path $source)) { throw "Addon folder not found: $source" }

New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path $source -DestinationPath $zip -CompressionLevel Optimal

$version = (Select-String -Path (Join-Path $source 'TimelessQuestion_Mists.toc') `
    -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()

Write-Host "Packaged version $version -> $zip"
Get-ChildItem $zip | Select-Object Name, Length
