<#
.SYNOPSIS
    Initialises and/or pushes every KoreForge.* repository to GitHub in
    dependency order.

.DESCRIPTION
    For each repository listed below the script does the following:

      1. If the repo does not yet have a local git repository, runs:
             git init -b main
             git add --all
             git commit -m "Initialized KoreForge.<name>"
             gh repo create koreforger/KoreForge.<name> --public --source . --remote origin --push

      2. If the repo already has a local git repository but has uncommitted
         changes (or untracked files), runs:
             git add --all
             git commit -m "chore: documentation and project updates"
             git push

      3. If the repo is already clean and fully pushed, reports it as up to date.

    Repositories are processed in dependency order so that downstream packages
    are pushed after the packages they depend on.

.PARAMETER GitHubOwner
    GitHub organisation or user account to create repos under.
    Defaults to 'koreforger'.

.PARAMETER DryRun
    Print every command that would run without actually executing it.

.PARAMETER WhatIf
    Alias for -DryRun.

.EXAMPLE
    .\scr\create-all-repos.ps1

.EXAMPLE
    .\scr\create-all-repos.ps1 -DryRun

.EXAMPLE
    .\scr\create-all-repos.ps1 -GitHubOwner myorg
#>
[CmdletBinding(SupportsShouldProcess)]
param (
    [string] $GitHubOwner = 'koreforger',

    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Resolve-Path "$PSScriptRoot\.."

# ---------------------------------------------------------------------------
# Repository list in push order (providers before consumers)
# ---------------------------------------------------------------------------
$repos = @(
    'KoreForge.Time',            # no KF dependencies
    'KoreForge.Logging',         # no KF dependencies
    'KoreForge.Logging.Serilog', # depends on Logging
    'KoreForge.Metrics',         # no KF dependencies
    'KoreForge.Metrics.AspNet',  # depends on Metrics
    'KoreForge.Processing',      # no KF dependencies
    'KoreForge.Settings',        # no KF dependencies
    'KoreForge.AppLifecycle',    # depends on Processing
    'KoreForge.Json',            # no KF dependencies
    'KoreForge.Data',             # no KF dependencies
    'KoreForge.OData',            # depends on Data
    'KoreForge.Jex',             # no KF dependencies
    'KoreForge.Web',             # no KF dependencies
    'KoreForge.Kafka',           # depends on Processing, Metrics, Logging, Time
    'KoreForge.Main',            # documentation-only repository
    'KoreForge.Templates'        # dotnet new templates (KafkaProcessor, ...)
)

# Apps use a different root (apps/) and potentially different GitHub repo names.
# Each entry: @{ Dir = relative path from workspace root; Repo = GitHub repo name }
$apps = @(
    @{ Dir = 'apps/EventProcessor'; Repo = 'EventProcessor' },
    @{ Dir = 'KF.Jex.Cli';           Repo = 'KF.Jex.Cli' },
    @{ Dir = 'KF.Jex.LanguageServer'; Repo = 'KF.Jex.LanguageServer' },
    @{ Dir = 'KF.Jex.VSCode';         Repo = 'KF.Jex.VSCode' }
)

# ---------------------------------------------------------------------------
function Invoke-Git {
    param([string[]] $Arguments)
    if ($DryRun -or $WhatIfPreference) {
        Write-Host "  [DRY-RUN] git $($Arguments -join ' ')" -ForegroundColor DarkYellow
        return
    }
    git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ')  exited with code $LASTEXITCODE"
    }
}

function Invoke-Gh {
    param([string[]] $Arguments)
    if ($DryRun -or $WhatIfPreference) {
        Write-Host "  [DRY-RUN] gh $($Arguments -join ' ')" -ForegroundColor DarkYellow
        return
    }
    gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments -join ' ')  exited with code $LASTEXITCODE"
    }
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║         KoreForge — Create & Push All Repos          ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

if ($DryRun -or $WhatIfPreference) {
    Write-Host '  *** DRY-RUN mode — no changes will be made ***' -ForegroundColor Yellow
    Write-Host ''
}

$success = @()
$skipped = @()
$failed  = @()

foreach ($repoName in $repos) {
    $repoPath = Join-Path $workspaceRoot $repoName

    Write-Host "── $repoName" -ForegroundColor Yellow

    if (-not (Test-Path $repoPath -PathType Container)) {
        Write-Host "  SKIP — folder not found: $repoPath" -ForegroundColor DarkGray
        $skipped += $repoName
        Write-Host ''
        continue
    }

    try {
        Push-Location $repoPath

        $gitDir = Join-Path $repoPath '.git'
        $hasGit = Test-Path $gitDir -PathType Container

        if (-not $hasGit) {
            # ── New repo — initialise, commit, create on GitHub, push ──
            Write-Host '  Initialising new git repository …' -ForegroundColor DarkGray
            Invoke-Git 'init', '-b', 'main'
            Invoke-Git 'add', '--all'
            Invoke-Git 'commit', '-m', "chore: initialise $repoName"
            Write-Host "  Creating GitHub repo $GitHubOwner/$repoName …" -ForegroundColor DarkGray
            Invoke-Gh 'repo', 'create', "$GitHubOwner/$repoName", '--public', '--source', '.', '--remote', 'origin', '--push'
            Write-Host "  ✓ Created and pushed." -ForegroundColor Green
            $success += $repoName
        }
        else {
            # ── Existing repo — check for uncommitted changes ──
            $statusOutput = git status --porcelain 2>&1
            $hasChanges   = $statusOutput | Where-Object { $_ -ne '' }

            if ($hasChanges) {
                Write-Host '  Committing and pushing uncommitted changes …' -ForegroundColor DarkGray
                Invoke-Git 'add', '--all'
                Invoke-Git 'commit', '-m', 'chore: documentation and project updates'
                Invoke-Git 'push'
                Write-Host '  ✓ Committed and pushed.' -ForegroundColor Green
                $success += $repoName
            }
            else {
                $behind = git rev-list '@{u}..HEAD' 2>$null | Measure-Object | Select-Object -ExpandProperty Count
                if ($behind -gt 0) {
                    Write-Host "  Pushing $behind unpushed commit(s) …" -ForegroundColor DarkGray
                    Invoke-Git 'push'
                    Write-Host '  ✓ Pushed.' -ForegroundColor Green
                    $success += $repoName
                }
                else {
                    Write-Host '  Already up to date.' -ForegroundColor DarkGray
                    $skipped += $repoName
                }
            }
        }
    }
    catch {
        Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
        $failed += $repoName
    }
    finally {
        Pop-Location
    }

    Write-Host ''
}

# ---------------------------------------------------------------------------
# Apps (separate folder roots, may use different GitHub repo names)
# ---------------------------------------------------------------------------
foreach ($app in $apps) {
    $repoPath = Join-Path $workspaceRoot $app.Dir
    $repoName = $app.Repo

    Write-Host "── $repoName  (app)" -ForegroundColor Yellow

    if (-not (Test-Path $repoPath -PathType Container)) {
        Write-Host "  SKIP — folder not found: $repoPath" -ForegroundColor DarkGray
        $skipped += $repoName
        Write-Host ''
        continue
    }

    try {
        Push-Location $repoPath

        $gitDir = Join-Path $repoPath '.git'
        $hasGit = Test-Path $gitDir -PathType Container

        if (-not $hasGit) {
            Write-Host '  Initialising new git repository …' -ForegroundColor DarkGray
            Invoke-Git 'init', '-b', 'main'
            Invoke-Git 'add', '--all'
            Invoke-Git 'commit', '-m', "chore: initialise $repoName"
            Write-Host "  Creating GitHub repo $GitHubOwner/$repoName …" -ForegroundColor DarkGray
            Invoke-Gh 'repo', 'create', "$GitHubOwner/$repoName", '--public', '--source', '.', '--remote', 'origin', '--push'
            Write-Host '  ✓ Created and pushed.' -ForegroundColor Green
            $success += $repoName
        }
        else {
            $hasRemote = (git remote 2>&1 | Out-String).Trim() -ne ''
            $statusOutput = git status --porcelain 2>&1
            $hasChanges   = $statusOutput | Where-Object { $_ -ne '' }

            if ($hasChanges) {
                Write-Host '  Committing uncommitted changes …' -ForegroundColor DarkGray
                Invoke-Git 'add', '--all'
                Invoke-Git 'commit', '-m', 'chore: update EventProcessor — Kafka StoreOffset fix, diagnostic pipeline stages, catchup benchmark'
            }

            if (-not $hasRemote) {
                Write-Host "  Creating GitHub repo $GitHubOwner/$repoName …" -ForegroundColor DarkGray
                Invoke-Gh 'repo', 'create', "$GitHubOwner/$repoName", '--public', '--source', '.', '--remote', 'origin', '--push'
                Write-Host '  ✓ Created and pushed.' -ForegroundColor Green
            }
            else {
                $behind = git rev-list '@{u}..HEAD' 2>$null | Measure-Object | Select-Object -ExpandProperty Count
                if ($behind -gt 0 -or $hasChanges) {
                    Invoke-Git 'push'
                    Write-Host '  ✓ Pushed.' -ForegroundColor Green
                }
                else {
                    Write-Host '  Already up to date.' -ForegroundColor DarkGray
                    $skipped += $repoName
                    Pop-Location
                    Write-Host ''
                    continue
                }
            }
            $success += $repoName
        }
    }
    catch {
        Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
        $failed += $repoName
    }
    finally {
        Pop-Location
    }

    Write-Host ''
}

# ---------------------------------------------------------------------------
Write-Host '══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Summary' -ForegroundColor Cyan
Write-Host '══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
if ($success.Count -gt 0) { Write-Host "  ✓ Pushed ($($success.Count)):  $($success -join ', ')" -ForegroundColor Green }
if ($skipped.Count -gt 0) { Write-Host "  - Skipped ($($skipped.Count)): $($skipped -join ', ')" -ForegroundColor DarkGray }
if ($failed.Count  -gt 0) { Write-Host "  ✗ Failed ($($failed.Count)):  $($failed -join ', ')"  -ForegroundColor Red }
Write-Host ''
