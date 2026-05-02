#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifactRoot = Join-Path $WorkspaceRoot 'artifacts'
$reportFolders = @(
    'script-runner/logs',
    'repos',
    'test-results',
    'coverage',
    'reports'
)

foreach ($folder in $reportFolders) {
    $path = Join-Path $artifactRoot $folder
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $path -ItemType Directory -Force | Out-Null
}

Write-Host "Report artifacts cleaned: $artifactRoot" -ForegroundColor Green