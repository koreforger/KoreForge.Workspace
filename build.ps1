#Requires -Version 7.2
[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive,

    [Parameter(ParameterSetName = 'CleanAll')]
    [switch]$CleanArtifacts,

    [Parameter(ParameterSetName = 'CleanPackages')]
    [switch]$CleanPackages,

    [Parameter(ParameterSetName = 'CleanReports')]
    [switch]$CleanReports,

    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot

if ($CleanArtifacts) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scr/clean-artifacts.ps1')
    exit $LASTEXITCODE
}

if ($CleanPackages) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scr/clean-artifact-packages.ps1')
    exit $LASTEXITCODE
}

if ($CleanReports) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scr/clean-artifact-reports.ps1')
    exit $LASTEXITCODE
}

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'builder.ps1') -Configuration $Configuration
exit $LASTEXITCODE