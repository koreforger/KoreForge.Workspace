#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Version = '1.0.1-alpha',

    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'clean-artifacts.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'pack-local-feed.ps1') `
    -Version $Version `
    -Configuration $Configuration `
    -CleanFeed

exit $LASTEXITCODE