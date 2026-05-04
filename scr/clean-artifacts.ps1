#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifactRoot = Join-Path $WorkspaceRoot 'artifacts'

if (Test-Path $artifactRoot) {
    # Remove subdirectories (except preserved caches)
    Get-ChildItem -Path $artifactRoot -Directory |
        Where-Object { $_.Name -notin @('script-runner', 'nuget-cache') } |
        ForEach-Object { Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

    # Remove loose generated files at the artifacts root (binlogs, test-run captures, logs)
    Get-ChildItem -Path $artifactRoot -File |
        Where-Object { $_.Extension -in @('.binlog', '.txt', '.log') } |
        ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
}

$repoRoots = @('eco-system', 'tools', 'event', 'eco-web') |
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