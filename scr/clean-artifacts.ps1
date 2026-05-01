#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifactRoot = Join-Path $WorkspaceRoot 'artifacts'

if (Test-Path $artifactRoot) {
    Remove-Item -Path $artifactRoot -Recurse -Force
}

$repoRoots = @('packages', 'tools', 'event', 'npm') |
    ForEach-Object { Join-Path $WorkspaceRoot $_ } |
    Where-Object { Test-Path $_ }

$staleOutputNames = @(
    'bin',
    'obj',
    'out',
    'artifacts',
    'TestResults',
    'coverage-report',
    'BenchmarkDotNet.Artifacts',
    '.vs'
)

foreach ($repoRoot in $repoRoots) {
    foreach ($name in $staleOutputNames) {
        Get-ChildItem -Path $repoRoot -Directory -Recurse -Filter $name -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$folders = @(
    'packages',
    'packages/staging',
    'script-runner/logs',
    'repos',
    'test-results',
    'coverage',
    'reports',
    'zips'
)

foreach ($folder in $folders) {
    New-Item -Path (Join-Path $artifactRoot $folder) -ItemType Directory -Force | Out-Null
}

Write-Host "Artifacts cleaned: $artifactRoot" -ForegroundColor Green