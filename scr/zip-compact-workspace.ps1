<#
.SYNOPSIS
    Creates a compact KoreForge workspace zip that keeps code and excludes binaries/caches.

.DESCRIPTION
    Unlike zip-workspace.ps1, this script does not clean/delete workspace content.
    It creates a filtered archive that includes source, scripts, docs, and config files,
    while excluding build outputs, test artefacts, and downloaded package caches.

    Primary exclusions:
      - bin/, obj/, artifacts/, TestResults/, coverage-report/, .vs/
      - node_modules/, .nuget/, packages/
      - BenchmarkDotNet.Artifacts/, dist/
      - generated web assets under wwwroot/assets/
      - .git/

    Additional binary file extension exclusions are applied as a safety net.

.PARAMETER WorkspaceRoot
    Root folder of the KoreForge workspace.
    Defaults to the parent of the folder that contains this script.

.PARAMETER OutputPath
    Full path to the output zip file.
    Defaults to: <workspace-root>\artifacts\zips\KoreForge-compact-{yyyy-MM-dd}.zip

.PARAMETER Overwrite
    If set, overwrite OutputPath when it already exists.

.EXAMPLE
    .\scr\zip-compact-workspace.ps1

.EXAMPLE
    .\scr\zip-compact-workspace.ps1 -Verbose -Overwrite
#>
[CmdletBinding()]
param (
    [string] $WorkspaceRoot = (Split-Path $PSScriptRoot -Parent),
    [string] $OutputPath,
    [switch] $Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $WorkspaceRoot -PathType Container)) {
    throw "WorkspaceRoot does not exist: $WorkspaceRoot"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $dateSuffix = Get-Date -Format 'yyyy-MM-dd'
    $archiveName = "KoreForge-compact-$dateSuffix.zip"
    $archiveRoot = Join-Path $WorkspaceRoot 'artifacts\zips'
    New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null
    $OutputPath = Join-Path $archiveRoot $archiveName
}

$workspaceRootFull = (Resolve-Path $WorkspaceRoot).Path

# Directory-name filters (case-insensitive, anywhere in path)
$excludedDirNames = @(
    '.git',
    '.vs',
    'bin',
    'obj',
    'artifacts',
    'testresults',
    'coverage-report',
    'benchmarkdotnet.artifacts',
    'node_modules',
    '.nuget',
    'packages',
    'dist'
)

# File extension filters as final safety net for binary outputs.
$excludedFileExtensions = @(
    '.dll', '.exe', '.pdb', '.so', '.dylib',
    '.nupkg', '.snupkg', '.cache', '.ilk', '.idb', '.obj'
)

function Test-IsExcludedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,
        [Parameter(Mandatory = $true)]
        [string[]] $ExcludedDirNames,
        [Parameter(Mandatory = $true)]
        [string[]] $ExcludedFileExtensions
    )

    $normalized = $RelativePath.Replace('\', '/').ToLowerInvariant()

    # Exclude generated frontend bundles and coverage artifacts.
    if ($normalized -like '*/wwwroot/assets/*' -or $normalized -like '*/coverage.json') {
        return $true
    }

    $segments = $normalized.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)

    foreach ($segment in $segments) {
        if ($ExcludedDirNames -contains $segment) {
            return $true
        }
    }

    $ext = [System.IO.Path]::GetExtension($normalized)
    if (-not [string]::IsNullOrEmpty($ext) -and ($ExcludedFileExtensions -contains $ext)) {
        return $true
    }

    return $false
}

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║      KoreForge Workspace — Compact Source Zip       ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Workspace : $workspaceRootFull" -ForegroundColor DarkGray
Write-Host "  Output    : $OutputPath" -ForegroundColor DarkGray
Write-Host ''

if (Test-Path $OutputPath) {
    if (-not $Overwrite) {
        throw "Archive already exists. Re-run with -Overwrite or provide -OutputPath: $OutputPath"
    }

    Write-Verbose "Removing existing archive: $OutputPath"
    Remove-Item -Path $OutputPath -Force
}

$filesToZip = New-Object System.Collections.Generic.List[string]
$includedCount = 0
$excludedCount = 0

Get-ChildItem -Path $workspaceRootFull -Recurse -File -Force | ForEach-Object {
    $fullPath = $_.FullName
    $relativePath = [System.IO.Path]::GetRelativePath($workspaceRootFull, $fullPath)

    if (Test-IsExcludedPath -RelativePath $relativePath -ExcludedDirNames $excludedDirNames -ExcludedFileExtensions $excludedFileExtensions) {
        $excludedCount++
        return
    }

    $filesToZip.Add($fullPath)
    $includedCount++
}

if ($includedCount -eq 0) {
    throw 'No files selected for archive after exclusions.'
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
try {
    $zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($file in $filesToZip) {
            $entryName = [System.IO.Path]::GetRelativePath($workspaceRootFull, $file).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $file,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }
}
finally {
    $zipStream.Dispose()
}

$sizeMB = [math]::Round((Get-Item $OutputPath).Length / 1MB, 1)
Write-Host "  Included files : $includedCount" -ForegroundColor Green
Write-Host "  Excluded files : $excludedCount" -ForegroundColor DarkGray
Write-Host "  Archive size   : $sizeMB MB" -ForegroundColor Green
Write-Host ''
Write-Host '✓ Compact archive complete.' -ForegroundColor Green
Write-Host ''
