#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = Join-Path $WorkspaceRoot 'artifacts/packages'

if (Test-Path $packageRoot) {
    Remove-Item -Path $packageRoot -Recurse -Force
}

New-Item -Path (Join-Path $packageRoot 'staging') -ItemType Directory -Force | Out-Null
Write-Host "Package artifacts cleaned: $packageRoot" -ForegroundColor Green