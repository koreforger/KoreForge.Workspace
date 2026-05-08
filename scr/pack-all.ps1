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
$artifactsRoot = Join-Path $root 'artifacts'
$packageRoot = Join-Path $artifactsRoot 'packages'
$stagingRoot = Join-Path $packageRoot 'staging'
$nugetConfig = Join-Path $root 'NuGet.config'
New-Item -Path $packageRoot -ItemType Directory -Force | Out-Null
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
New-Item -Path $stagingRoot -ItemType Directory -Force | Out-Null

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
    'KoreForge.Scripts',
    'KoreForge.Settings',
    'KoreForge.Web',
    'KoreForge.SwaggerControllers',
    'KoreForge.Kafka'
)

# Templates are packed separately (no MinVer, no AssemblyVersion).
$templateRepos = @(
    'KoreForge.Templates'
)

$totalPacked = 0

foreach ($repo in $repos) {
    $repoDir = Join-Path $root (Join-Path 'eco-system' $repo)
    if (-not (Test-Path $repoDir)) {
        Write-Warning "Repo not found: $repo"
        continue
    }

    $sln = Get-ChildItem -Path $repoDir -Filter '*.slnx' -File | Select-Object -First 1
    if (-not $sln) {
        Write-Warning "No .slnx in $repo"
        continue
    }

    # Pack only the src/ packable projects to avoid test projects referencing stale
    # published versions of their own package (VersionOverride issues during restore).
    $srcDir = Join-Path $repoDir 'src'
    $packableProjects = @()
    if (Test-Path $srcDir) {
        $packableProjects = @(Get-ChildItem -Path $srcDir -Filter '*.csproj' -Recurse -File |
            Where-Object {
                $content = Get-Content $_.FullName -Raw
                $content -notmatch '<IsPackable>\s*false\s*</IsPackable>'
            })
    }

    if ($packableProjects.Count -eq 0) {
        Write-Warning "No packable src projects in $repo"
        continue
    }

    $artifactsDir = Join-Path $stagingRoot $repo
    $repoBuildRoot = Join-Path $artifactsRoot (Join-Path 'repos' (Join-Path $repo 'build'))
    $repoBinRoot   = Join-Path $repoBuildRoot 'bin'
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

    # Multi-pass: retry failed projects so that sibling-dependency ordering is
    # resolved automatically (e.g. Contracts before AspNetCore in the same repo).
    $pendingProjects = [System.Collections.Generic.List[object]]$packableProjects
    $maxPasses = $packableProjects.Count + 1

    while ($pendingProjects.Count -gt 0 -and $maxPasses -gt 0) {
        $maxPasses--
        $stillFailing = [System.Collections.Generic.List[object]]@()

        foreach ($project in $pendingProjects) {
            # Use /p:Version to override MinVer, /p:MinVerSkip=true to disable MinVer tag lookup.
            # KoreForgeComponentBinRoot tells multi-DLL bundling csproj (e.g. KoreForge.Logging)
            # where --artifacts-path routed the component DLLs; KoreForgeArtifactsConfiguration
            # must be lowercase to match the artifacts-path directory convention.
            $dotnetArgs = @(
                'pack', $project.FullName,
                '--configuration', 'Release',
                "/p:Version=$Version",
                '/p:MinVerSkip=true',
                "/p:AssemblyVersion=$asmVer",
                "/p:FileVersion=$fileVer",
                '/p:ContinuousIntegrationBuild=true',
                "/p:KoreForgeComponentBinRoot=$repoBinRoot",
                '/p:KoreForgeArtifactsConfiguration=release',
                "/p:RestoreConfigFile=$nugetConfig",
                '--artifacts-path', $repoBuildRoot,
                '-o', $artifactsDir
            )

            dotnet @dotnetArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                $stillFailing.Add($project)
            } else {
                # Copy any newly produced packages to the local feed immediately so that
                # sibling packages in the same repo can restore them in the next pass.
                $justPacked = Get-ChildItem -Path $artifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue
                foreach ($pkg in $justPacked) {
                    $dest = Join-Path $packageRoot $pkg.Name
                    if (-not (Test-Path $dest)) {
                        Copy-Item -Path $pkg.FullName -Destination $dest -Force
                    }
                }
            }
        }

        # If no progress was made this pass, stop retrying to avoid infinite loop.
        if ($stillFailing.Count -eq $pendingProjects.Count) {
            foreach ($p in $stillFailing) {
                Write-Error "Failed to pack $($p.Name) in $repo"
            }
            break
        }
        $pendingProjects = $stillFailing
    }
    if ($pendingProjects.Count -gt 0 -and $maxPasses -eq 0) {
        foreach ($p in $pendingProjects) {
            Write-Error "Failed to pack $($p.Name) in $repo (max passes exceeded)"
        }
    }

    $packages = Get-ChildItem -Path $artifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        Copy-Item -Path $pkg.FullName -Destination (Join-Path $packageRoot $pkg.Name) -Force
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
    $repoDir = Join-Path $root (Join-Path 'eco-system' $repo)
    if (-not (Test-Path $repoDir)) { Write-Warning "Repo not found: $repo"; continue }

    $csproj = Get-ChildItem -Path $repoDir -Filter '*.csproj' -File | Select-Object -First 1
    if (-not $csproj) { Write-Warning "No .csproj in $repo"; continue }

    $artifactsDir = Join-Path $stagingRoot $repo
    $repoBuildRoot = Join-Path $artifactsRoot (Join-Path 'repos' (Join-Path $repo 'build'))
    if (Test-Path $artifactsDir) { Remove-Item $artifactsDir -Recurse -Force }

    Write-Host ''
    Write-Host "══ Packing $repo ($Version) ══" -ForegroundColor Cyan

    dotnet pack $csproj.FullName `
        --configuration Release `
        --artifacts-path $repoBuildRoot `
        -o $artifactsDir `
        /p:PackageVersion=$Version 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pack $repo"
        continue
    }

    $packages = Get-ChildItem -Path $artifactsDir -Filter '*.nupkg' -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        Copy-Item -Path $pkg.FullName -Destination (Join-Path $packageRoot $pkg.Name) -Force
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
    Where-Object { $_.FullName -like "$packageRoot*" } |
    ForEach-Object { Write-Host ('  ' + $_.FullName) }
