#Requires -Version 7.2
<#
.SYNOPSIS
    Rebuilds, updates dependency pins, packs, and publishes all KoreForge NuGet packages.

.DESCRIPTION
    Orchestration steps (in order):
      1. Ask for release version (or accept -Version parameter).
      2. For each repo that has scr/update-dependencies.ps1, call it with -Version.
      3. Run scr/pack-all.ps1 -Version <version> to pack every repo locally.
      4. Push every *.nupkg from artifacts/ directories to NuGet.org.

    Reads the NuGet API key from nuget-api.key.txt at the workspace root.
    Repos with cross-repo dependency pins (KoreForge.Json, KoreForge.Kafka) have
    their own scr/update-dependencies.ps1 that updates Directory.Packages.props.

.PARAMETER Version
    Version to release (e.g. 1.2.0 or 1.2.0-beta.1). Prompted if not provided.
#>
[CmdletBinding()]
param(
    [string] $Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent

# ── Version ───────────────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Read-Host 'NuGet release version (e.g. 1.2.0)'
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw 'A version is required.'
    }
}
$Version = $Version.Trim()

Write-Host ''
Write-Host '══ KoreForge NuGet Release — Local Build ══' -ForegroundColor Cyan
Write-Host "   Version : $Version" -ForegroundColor Cyan
Write-Host ''

# ── API key ───────────────────────────────────────────────────────────────────
$keyFile = Join-Path $root '.local\secrets\nuget-api.key.txt'
if (-not (Test-Path $keyFile)) {
    throw "NuGet API key file not found: $keyFile"
}
$apiKey = (Get-Content $keyFile -Raw).Trim()

# ── Update dependencies — repos that pin sibling KoreForge versions ───────────
Write-Host 'Updating dependency version pins …' -ForegroundColor Cyan
$repos = @(Get-ChildItem -Path $root -Directory | Sort-Object Name)
foreach ($repo in $repos) {
    $updateScript = Join-Path $repo.FullName 'scr\update-dependencies.ps1'
    if (Test-Path $updateScript) {
        Write-Host "  → $($repo.Name)" -ForegroundColor DarkCyan
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $updateScript -Version $Version
        if ($LASTEXITCODE -ne 0) {
            throw "$($repo.Name)/scr/update-dependencies.ps1 failed with exit code $LASTEXITCODE"
        }
    }
}

# ── Pack all ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Packing all packages …' -ForegroundColor Cyan
$packScript = Join-Path $root 'scr\pack-all.ps1'
& pwsh -NoProfile -ExecutionPolicy Bypass -File $packScript -Version $Version
if ($LASTEXITCODE -ne 0) {
    throw "pack-all.ps1 failed with exit code $LASTEXITCODE"
}

# ── Push all ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Pushing packages to NuGet.org …' -ForegroundColor Cyan

$packageRoot = Join-Path $root 'artifacts/packages'
$packages = @(Get-ChildItem -Path $packageRoot -Filter '*.nupkg' -File -ErrorAction SilentlyContinue | Sort-Object FullName)

if ($packages.Count -eq 0) {
    throw 'No .nupkg files found under artifacts/ after pack.'
}

$pushed  = 0
$skipped = 0
$failed  = 0

foreach ($pkg in $packages) {
    Write-Host "  Pushing $($pkg.Name) …" -ForegroundColor DarkCyan

    $output = dotnet nuget push $pkg.FullName `
        --api-key $apiKey `
        --source https://api.nuget.org/v3/index.json `
        --skip-duplicate 2>&1

    $output | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) {
        if ($output -match 'already exists') {
            Write-Host "  ~ $($pkg.Name) (already on NuGet — skipped)" -ForegroundColor DarkYellow
            $skipped++
        }
        else {
            Write-Host "  ✓ $($pkg.Name)" -ForegroundColor Green
            $pushed++
        }
    }
    else {
        Write-Warning "  ✗ $($pkg.Name) — push failed (exit $LASTEXITCODE)"
        $failed++
    }
}

Write-Host ''
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host "  Version : $Version"  -ForegroundColor Cyan
Write-Host "  Pushed  : $pushed"   -ForegroundColor Green
if ($skipped -gt 0) { Write-Host "  Skipped : $skipped (already published)" -ForegroundColor DarkYellow }
if ($failed  -gt 0) { Write-Host "  Failed  : $failed"  -ForegroundColor Red }
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}
