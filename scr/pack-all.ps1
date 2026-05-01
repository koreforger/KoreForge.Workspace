<#
.SYNOPSIS
    Packs all KoreForge NuGet packages with a specified version.
.PARAMETER Version
    The version to stamp on all packages (e.g. 0.0.2-alpha).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

# Repos in dependency order (leaves first).
$repos = @(
    'KoreForge.Time',
    'KoreForge.Json',
    'KoreForge.Data',
    'KoreForge.OData',
    'KoreForge.Logging',
    'KoreForge.Logging.Serilog',
    'KoreForge.Jex',
    'KoreForge.AppLifecycle',
    'KoreForge.Metrics',
    'KoreForge.Metrics.AspNet',
    'KoreForge.Monitoring',
    'KoreForge.Processing',
    'KoreForge.Settings',
    'KoreForge.Web',
    'KoreForge.Kafka'
)

# Templates are packed separately (no MinVer, no AssemblyVersion).
$templateRepos = @(
    'KoreForge.Templates'
)

$totalPacked = 0

foreach ($repo in $repos) {
    $repoDir = Join-Path $root $repo
    if (-not (Test-Path $repoDir)) {
        Write-Warning "Repo not found: $repo"
        continue
    }

    $sln = Get-ChildItem -Path $repoDir -Filter '*.slnx' -File | Select-Object -First 1
    if (-not $sln) {
        Write-Warning "No .slnx in $repo"
        continue
    }

    $artifactsDir = Join-Path $repoDir 'artifacts'
    if (Test-Path $artifactsDir) {
        Remove-Item $artifactsDir -Recurse -Force
    }

    Write-Host ''
    Write-Host "══ Packing $repo ($Version) ══" -ForegroundColor Cyan

    # Parse version parts for AssemblyVersion / FileVersion so the MinVer
    # ApplyMinVerVersion target doesn't produce empty-segment versions.
    $semver = $Version -replace '-.*$', ''   # strip pre-release suffix
    $parts  = $semver.Split('.')
    $asmVer  = "$($parts[0]).$($parts[1]).0.0"
    $fileVer = "$($parts[0]).$($parts[1]).$($parts[2]).0"

    # Use /p:Version to override MinVer, /p:MinVerSkip=true to disable MinVer tag lookup.
    dotnet pack $sln.FullName `
        --configuration Release `
        /p:Version=$Version `
        /p:MinVerSkip=true `
        /p:AssemblyVersion=$asmVer `
        /p:FileVersion=$fileVer `
        /p:ContinuousIntegrationBuild=true `
        --no-restore 2>&1

    if ($LASTEXITCODE -ne 0) {
        # Try with restore
        Write-Host "  Retrying with restore…" -ForegroundColor Yellow
        dotnet pack $sln.FullName `
            --configuration Release `
            /p:Version=$Version `
            /p:MinVerSkip=true `
            /p:AssemblyVersion=$asmVer `
            /p:FileVersion=$fileVer `
            /p:ContinuousIntegrationBuild=true 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to pack $repo"
            continue
        }
    }

    $packages = Get-ChildItem -Path $artifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        Write-Host "  ✓ $($pkg.Name)" -ForegroundColor Green
        $totalPacked++
    }
}

Write-Host ''
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Library packages: $totalPacked" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan

# ── Template packages ───────────────────────────────────────────────────────
Write-Host ''
Write-Host "── Packing templates ──────────────────────────────────" -ForegroundColor Cyan

foreach ($repo in $templateRepos) {
    $repoDir = Join-Path $root $repo
    if (-not (Test-Path $repoDir)) { Write-Warning "Repo not found: $repo"; continue }

    $csproj = Get-ChildItem -Path $repoDir -Filter '*.csproj' -File | Select-Object -First 1
    if (-not $csproj) { Write-Warning "No .csproj in $repo"; continue }

    $artifactsDir = Join-Path $repoDir 'artifacts'
    if (Test-Path $artifactsDir) { Remove-Item $artifactsDir -Recurse -Force }

    Write-Host ''
    Write-Host "══ Packing $repo ($Version) ══" -ForegroundColor Cyan

    dotnet pack $csproj.FullName `
        --configuration Release `
        /p:PackageVersion=$Version 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pack $repo"
        continue
    }

    $packages = Get-ChildItem -Path $artifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        Write-Host "  ✓ $($pkg.Name)" -ForegroundColor Green
        $totalPacked++
    }
}

Write-Host ''
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Total packages: $totalPacked" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Cyan

# List all packages
Write-Host ''
Write-Host "All .nupkg files:" -ForegroundColor Yellow
Get-ChildItem -Path $root -Recurse -Filter '*.nupkg' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like '*artifacts*' } |
    ForEach-Object { Write-Host ('  ' + $_.FullName) }
