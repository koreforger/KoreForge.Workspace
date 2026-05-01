<#
.SYNOPSIS
    Cleans build artefacts from every KoreForge.* repository and then zips the
    entire workspace into a dated archive.

.DESCRIPTION
    Step 1 — Clean
    Removes build artefacts from every KoreForge.* repository found under the
    workspace root.  The following folders are removed:
        obj/        TestResults/    artifacts/      coverage-report/    .vs/

    Compiled-output scr/ folders inside src/ and tst/ project trees are also
    removed.  The root-level scr/ folder of each repository is NEVER deleted
    (it contains automation scripts, not build outputs).

    Step 2 — Archive
    Creates a Zip archive of the entire workspace root (including .vscode and
    .github) at the parent directory with the filename:
        KoreForge-{yyyy-MM-dd}.zip

    If the archive already exists it is overwritten. Archives are written under
    the workspace artifact root.

.PARAMETER WorkspaceRoot
    Root folder of the KoreForge workspace.
    Defaults to the parent of the folder that contains this script.

.PARAMETER SkipClean
    If set, skips Step 1 and goes straight to archiving.

.PARAMETER SkipZip
    If set, only runs the clean step and does not create the archive.

.EXAMPLE
    .\scr\zip-workspace.ps1

.EXAMPLE
    .\scr\zip-workspace.ps1 -Verbose

.EXAMPLE
    .\scr\zip-workspace.ps1 -SkipClean    # archive without cleaning first
    .\scr\zip-workspace.ps1 -SkipZip      # clean only
#>
[CmdletBinding()]
param (
    [string] $WorkspaceRoot = (Split-Path $PSScriptRoot -Parent),
    [switch] $SkipClean,
    [switch] $SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║          KoreForge Workspace — Clean + Zip           ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Workspace : $WorkspaceRoot" -ForegroundColor DarkGray
Write-Host ''

# Folders to remove recursively from every project directory.
$junkFolders = @('obj', 'TestResults', 'artifacts', 'coverage-report', '.vs', 'node_modules')

# ---------------------------------------------------------------------------
# Step 1 — Clean build artefacts
# ---------------------------------------------------------------------------
if (-not $SkipClean) {
    Write-Host '── Step 1  Cleaning build artefacts …' -ForegroundColor Yellow
    Write-Host ''

    # Clean ALL child directories, not just KoreForge.* — the workspace also
    # contains apps/, KF.Jex.Cli/, KF.Jex.VSCode/, KF.Nuget.Integration.Tests/ etc.
    $repos = Get-ChildItem -Path $WorkspaceRoot -Directory |
             Where-Object { $_.Name -ne '.git' -and $_.Name -ne '.vscode' -and $_.Name -ne '.github' }

    $removedCount = 0

    foreach ($repo in $repos) {
        Write-Verbose "  Scanning $($repo.Name)"

        foreach ($junk in $junkFolders) {
            $candidates = Get-ChildItem -Path $repo.FullName -Recurse -Directory `
                              -Filter $junk -ErrorAction SilentlyContinue

            foreach ($dir in $candidates) {
                if (-not (Test-Path $dir.FullName)) { continue }
                Write-Verbose "    Removing $($dir.FullName)"
                Remove-Item -Path $dir.FullName -Recurse -Force
                $removedCount++
            }
        }

        # Remove compiled-output scr/ folders recursively.
        # Protect root-level scr/ only if it contains scripts (automation folders).
        $binCandidates = Get-ChildItem -Path $repo.FullName -Recurse -Directory `
                             -Filter 'bin' -ErrorAction SilentlyContinue
        foreach ($dir in $binCandidates) {
            if (-not (Test-Path $dir.FullName)) { continue }
            if ($dir.Parent.FullName -eq $repo.FullName) {
                $hasScripts = Get-ChildItem -Path $dir.FullName -Filter '*.ps1' -File -ErrorAction SilentlyContinue
                if ($hasScripts) { continue }   # skip automation scr/ with scripts
            }
            Write-Verbose "    Removing $($dir.FullName)"
            Remove-Item -Path $dir.FullName -Recurse -Force
            $removedCount++
        }
    }

    Write-Host "  Removed $removedCount artefact folder(s)." -ForegroundColor Green
    Write-Host ''
    Write-Host '✓ Clean complete.' -ForegroundColor Green
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Step 2 — Archive workspace
# ---------------------------------------------------------------------------
if (-not $SkipZip) {
    Write-Host '── Step 2  Creating workspace archive …' -ForegroundColor Yellow
    Write-Host ''

    $dateSuffix   = Get-Date -Format 'yyyy-MM-dd'
    $archiveName  = "KoreForge-$dateSuffix.zip"
    $archiveRoot  = Join-Path $WorkspaceRoot 'artifacts\zips'
    New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
    $archivePath  = Join-Path $archiveRoot $archiveName

    if (Test-Path $archivePath) {
        Write-Verbose "  Removing existing archive: $archivePath"
        Remove-Item -Path $archivePath -Force
    }

    Write-Host "  Source  : $WorkspaceRoot" -ForegroundColor DarkGray
    Write-Host "  Archive : $archivePath"   -ForegroundColor DarkGray
    Write-Host ''

    # Compress-Archive does not support piped paths with -DestinationPath into parent if the
    # parent directory is the same as source; use .NET directly for reliability.
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $WorkspaceRoot,
        $archivePath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false   # includeBaseDirectory
    )

    $sizeMB = [math]::Round((Get-Item $archivePath).Length / 1MB, 1)
    Write-Host "  Created $archiveName ($sizeMB MB)" -ForegroundColor Green
    Write-Host ''
    Write-Host '✓ Archive complete.' -ForegroundColor Green
    Write-Host ''
}

# ---------------------------------------------------------------------------
Write-Host '══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Done.' -ForegroundColor Cyan
Write-Host '══════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
