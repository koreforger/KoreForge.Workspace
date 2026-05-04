#Requires -Version 7.2
<#
.SYNOPSIS
    Create or delete a GitFlow feature branch across selected repositories.

.DESCRIPTION
    Presents a console GUI listing all git repositories in the workspace.
    You select which repos to target, then choose to open or close a branch.

    OPEN  — creates 'feature/<Name>' off 'development' in each selected repo
            and pushes the branch to origin.

    CLOSE — deletes 'feature/<Name>' locally and from origin in each selected repo.
            The branch must be fully merged into development before closing;
            use -Force to skip that check.

.PARAMETER Root
    Workspace root folder. Defaults to the parent of this script's directory.

.PARAMETER Force
    When closing, skip the merged-check and force-delete the local branch.
#>

[CmdletBinding()]
param(
    [string] $Root  = (Split-Path $PSScriptRoot -Parent),
    [switch] $Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Module
# ---------------------------------------------------------------------------
$moduleName = "Microsoft.PowerShell.ConsoleGuiTools"
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "Installing module: $moduleName" -ForegroundColor Yellow
    Install-Module $moduleName -Scope CurrentUser -Force -AllowClobber
}
Import-Module $moduleName -ErrorAction Stop

# ---------------------------------------------------------------------------
# Discover git repos
# ---------------------------------------------------------------------------
function Get-GitRepositories {
    param([string] $RootPath)

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    Get-ChildItem -Path $RootPath -Directory |
    ForEach-Object {
        $top = $_
        if (Test-Path (Join-Path $top.FullName ".git")) {
            if ($seen.Add($top.FullName)) { $top }
        }
        else {
            Get-ChildItem -Path $top.FullName -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
            ForEach-Object { if ($seen.Add($_.FullName)) { $_ } }
        }
    }
}

function Get-RepoBranch {
    param([string] $Path)
    git -C $Path rev-parse --abbrev-ref HEAD 2>$null
}

function Get-RepoRemoteBranches {
    param([string] $Path)
    git -C $Path branch -r 2>$null | ForEach-Object { $_.Trim() }
}

# ---------------------------------------------------------------------------
# Build display list
# ---------------------------------------------------------------------------
$rootPath = (Resolve-Path $Root).Path
$allRepos = @(Get-GitRepositories -RootPath $rootPath | Sort-Object {
    # group by parent folder, then name, so eco-system/* cluster together
    "$($_.Parent.Name)\$($_.Name)"
})

if ($allRepos.Count -eq 0) {
    Write-Host "No git repositories found under '$rootPath'." -ForegroundColor Yellow
    return
}

$repoRows = $allRepos | ForEach-Object {
    $branch  = Get-RepoBranch -Path $_.FullName
    $group   = $_.Parent.Name
    $hasRemote = (git -C $_.FullName remote 2>$null) -ne $null
    [pscustomobject]@{
        Name       = $_.Name
        Group      = $group
        Branch     = $branch
        HasRemote  = $hasRemote
        FullPath   = $_.FullName
    }
}

# ---------------------------------------------------------------------------
# Step 1 — choose action
# ---------------------------------------------------------------------------
$actionRow = @(
    [pscustomobject]@{ Action = "open";  Label = "Open  — create feature branch off development" }
    [pscustomobject]@{ Action = "close"; Label = "Close — delete feature branch locally and from origin" }
) | Out-ConsoleGridView -OutputMode Single -Title "Feature branch — choose action"

if (-not $actionRow) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    return
}

$action = $actionRow.Action

# ---------------------------------------------------------------------------
# Step 2 — enter branch name
# ---------------------------------------------------------------------------
$featureName = (Read-Host "Feature name (without 'feature/' prefix)").Trim()
if ([string]::IsNullOrWhiteSpace($featureName)) {
    Write-Host "No name entered. Cancelled." -ForegroundColor Yellow
    return
}
# Sanitise: spaces → hyphens, strip chars unsafe in branch names
$featureName = $featureName -replace '\s+', '-' -replace '[^\w.\-/]', ''
$branchName  = "feature/$featureName"

Write-Host ""
Write-Host "Branch  : $branchName" -ForegroundColor Cyan
Write-Host "Action  : $action"     -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Step 3 — select repos via grid
# ---------------------------------------------------------------------------
if ($action -eq "open") {
    $titleSuffix = "select repos to CREATE '$branchName' in"
    # Pre-filter: exclude repos already on or already having this branch
    $candidates = $repoRows | Where-Object {
        $existing = git -C $_.FullPath branch --list $branchName 2>$null
        -not $existing
    }
}
else {
    $titleSuffix = "select repos to DELETE '$branchName' from"
    # Pre-filter: only repos that have this branch locally or remotely
    $candidates = $repoRows | Where-Object {
        $localExists  = (git -C $_.FullPath branch --list $branchName 2>$null) -ne ''
        $remoteExists = (Get-RepoRemoteBranches -Path $_.FullPath) -contains "origin/$branchName"
        $localExists -or $remoteExists
    }
}

if ($candidates.Count -eq 0) {
    if ($action -eq "open") {
        Write-Host "All repos already have branch '$branchName'." -ForegroundColor Yellow
    }
    else {
        Write-Host "No repos found with branch '$branchName'." -ForegroundColor Yellow
    }
    return
}

$selected = $candidates |
    Select-Object Group, Name, Branch, HasRemote, FullPath |
    Out-ConsoleGridView -OutputMode Multiple -Title "Feature branch — $titleSuffix (SPACE to multi-select)"

if (-not $selected -or $selected.Count -eq 0) {
    Write-Host "No repos selected." -ForegroundColor Yellow
    return
}

Write-Host ""

# ---------------------------------------------------------------------------
# Step 4 — execute
# ---------------------------------------------------------------------------
$results = foreach ($repo in $selected) {
    $p      = $repo.FullPath
    $name   = $repo.Name
    $ok     = $true
    $detail = ""

    if ($action -eq "open") {
        # Ensure we're on development or can reach it
        $currentBranch = Get-RepoBranch -Path $p
        if ($currentBranch -ne "development") {
            Write-Host "  [$name] Switching to development..." -ForegroundColor DarkGray
            git -C $p checkout development 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $ok     = $false
                $detail = "Could not checkout development"
            }
        }

        if ($ok) {
            # Pull latest development
            if ($repo.HasRemote) {
                git -C $p pull --ff-only origin development 2>&1 | Out-Null
            }

            # Create and push branch
            git -C $p checkout -b $branchName 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $ok     = $false
                $detail = "Failed to create branch"
            }
        }

        if ($ok -and $repo.HasRemote) {
            $pushOut = git -C $p push -u origin $branchName 2>&1
            if ($LASTEXITCODE -ne 0) {
                $ok     = $false
                $detail = "Push failed: $pushOut"
            }
            else {
                $detail = "Created and pushed"
            }
        }
        elseif ($ok) {
            $detail = "Created locally (no remote)"
        }
    }
    else {
        # close
        $currentBranch = Get-RepoBranch -Path $p

        # Switch off the branch if we're on it
        if ($currentBranch -eq $branchName) {
            git -C $p checkout development 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $ok     = $false
                $detail = "Could not switch off feature branch to development"
            }
        }

        if ($ok) {
            # Delete local branch
            $localExists = (git -C $p branch --list $branchName 2>$null) -ne ''
            if ($localExists) {
                $deleteFlag = if ($Force) { "-D" } else { "-d" }
                $delOut = git -C $p branch $deleteFlag $branchName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $ok     = $false
                    $detail = "Local delete failed (not merged? use -Force): $delOut"
                }
            }
        }

        if ($ok) {
            # Delete remote branch
            $remoteExists = (Get-RepoRemoteBranches -Path $p) -contains "origin/$branchName"
            if ($remoteExists -and $repo.HasRemote) {
                $delRemote = git -C $p push origin --delete $branchName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    # Non-fatal — branch may already be gone on remote
                    $detail = "Local deleted; remote delete failed: $delRemote"
                    $ok     = $true  # still a partial success
                }
                else {
                    $detail = "Deleted locally and from origin"
                }
            }
            elseif ($ok) {
                $detail = "Deleted locally (no remote branch found)"
            }
        }
    }

    if ($ok) {
        Write-Host "✓ $name — $detail" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $name — $detail" -ForegroundColor Red
    }

    [pscustomobject]@{
        Repo    = $name
        Action  = $action
        Branch  = $branchName
        Success = $ok
        Detail  = $detail
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "───────" -ForegroundColor Cyan

$results | Format-Table `
    @{Name="Repo";    Expression={ $_.Repo };                                     Width=36 },
    @{Name="Action";  Expression={ $_.Action };                                   Width=8  },
    @{Name="Result";  Expression={ if ($_.Success) { "✓" } else { "✗" } };       Width=8  },
    @{Name="Detail";  Expression={ $_.Detail };                                            } `
    -Wrap

$failed = @($results | Where-Object { -not $_.Success })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) repo(s) had errors." -ForegroundColor Red
}
else {
    Write-Host "All done." -ForegroundColor Green
}
