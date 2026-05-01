#Requires -Version 7.2
<#
.SYNOPSIS
    Updates dependency pins and pushes git tags to trigger GitHub Actions NuGet publish.

.DESCRIPTION
    Orchestration steps (in order):
      1. Ask for release version (or accept -Version parameter).
      2. For each repo that has scr/update-dependencies.ps1, call it with -Version,
         then stage and commit the changed Directory.Packages.props.
      3. Push all repo commits (main branch) to GitHub.
      4. Push a version tag per repo (e.g. KoreForge.Time/v1.2.0) in dependency order.
         Each tag triggers the repo's publish-nuget.yml GitHub Actions workflow.

    Repos are tagged in dependency order so upstream packages are published before
    downstream ones request them from NuGet.org.

.PARAMETER Version
    Version to release (e.g. 1.2.0 or 1.2.0-beta.1). Prompted if not provided.

.PARAMETER DryRun
    Print what would happen without pushing any commits or tags.
#>
[CmdletBinding()]
param(
    [string] $Version,
    [switch] $DryRun
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
$tagVersion = "v$Version"

Write-Host ''
Write-Host '══ KoreForge NuGet Release — GitHub Actions ══' -ForegroundColor Cyan
Write-Host "   Version : $Version" -ForegroundColor Cyan
if ($DryRun) { Write-Host '   DRY RUN — no commits or tags will be pushed' -ForegroundColor Yellow }
Write-Host ''

# Repos in dependency order — must match pack-all.ps1.
# Templates are last; they have no GitHub publish-nuget.yml tag trigger by default.
$repoNames = @(
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
    'KoreForge.Processing',
    'KoreForge.Settings',
    'KoreForge.Web',
    'KoreForge.Kafka',
    'KoreForge.Templates'
)

function Invoke-Git {
    param([string] $RepoPath, [string[]] $Args, [string] $Description)
    Write-Host "    git $($Args -join ' ')" -ForegroundColor DarkGray
    if (-not $DryRun) {
        $result = git -C $RepoPath @Args 2>&1
        $result | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -ne 0) {
            throw "git $($Args -join ' ') failed in $RepoPath (exit $LASTEXITCODE)"
        }
    }
}

# ── Update dependencies and commit changed props files ────────────────────────
Write-Host 'Updating dependency version pins and committing …' -ForegroundColor Cyan
foreach ($repoName in $repoNames) {
    $repoPath      = Join-Path $root $repoName
    $updateScript  = Join-Path $repoPath 'scr\update-dependencies.ps1'

    if (-not (Test-Path $repoPath)) {
        Write-Warning "  Repo not found — skipping: $repoName"
        continue
    }

    if (Test-Path $updateScript) {
        Write-Host "  → $repoName" -ForegroundColor DarkCyan
        if (-not $DryRun) {
            & pwsh -NoProfile -ExecutionPolicy Bypass -File $updateScript -Version $Version
            if ($LASTEXITCODE -ne 0) {
                throw "$repoName/scr/update-dependencies.ps1 failed with exit code $LASTEXITCODE"
            }
        }
        else {
            Write-Host "    [DRY RUN] Would run update-dependencies.ps1 -Version $Version" -ForegroundColor Yellow
        }

        # Commit the updated props file
        Invoke-Git $repoPath @('add', 'Directory.Packages.props') -Description "stage props"
        Invoke-Git $repoPath @('commit', '--allow-empty', '-m', "build(deps): bump KoreForge sibling reference to $Version") -Description "commit props"
    }
}

# ── Push commits ──────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Pushing commits to GitHub …' -ForegroundColor Cyan
foreach ($repoName in $repoNames) {
    $repoPath = Join-Path $root $repoName
    if (-not (Test-Path $repoPath)) { continue }

    Write-Host "  → $repoName" -ForegroundColor DarkCyan
    Invoke-Git $repoPath @('push', 'origin', 'HEAD') -Description "push main"
}

# ── Tag and push — triggers GitHub Actions publish workflow ───────────────────
Write-Host ''
Write-Host 'Tagging and pushing to trigger GitHub Actions …' -ForegroundColor Cyan
foreach ($repoName in $repoNames) {
    $repoPath    = Join-Path $root $repoName
    $tagName     = "$repoName/$tagVersion"
    $publishYml  = Join-Path $repoPath '.github\workflows\publish-nuget.yml'
    # KoreForge.Kafka uses nuget-publish.yml — check either name
    $publishYml2 = Join-Path $repoPath '.github\workflows\nuget-publish.yml'

    if (-not (Test-Path $repoPath)) { continue }

    if (-not (Test-Path $publishYml) -and -not (Test-Path $publishYml2)) {
        Write-Host "  ~ $repoName — no publish workflow found, skipping tag" -ForegroundColor DarkYellow
        continue
    }

    Write-Host "  → $repoName  ($tagName)" -ForegroundColor DarkCyan
    Invoke-Git $repoPath @('tag', $tagName) -Description "create tag"
    Invoke-Git $repoPath @('push', 'origin', $tagName) -Description "push tag"
}

Write-Host ''
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host "  Version  : $Version"  -ForegroundColor Cyan
Write-Host "  Tags     : $($repoNames.Count) repos processed" -ForegroundColor Green
if ($DryRun) { Write-Host '  DRY RUN  : no changes were pushed' -ForegroundColor Yellow }
Write-Host '═══════════════════════════════════════════════════════' -ForegroundColor Cyan
