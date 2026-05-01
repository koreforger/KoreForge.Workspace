#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Version = '1.0.1-alpha',
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$CleanFeed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $root 'builder-v5.config.json'
if (-not (Test-Path $configPath)) { throw "Missing builder manifest: $configPath" }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$artifactsRoot = Join-Path $root $(if ($config.artifactsRoot) { $config.artifactsRoot } else { 'artifacts' })
$feed = Join-Path $root $config.localPackageFeed
$stagingRoot = Join-Path $artifactsRoot 'packages/staging'
New-Item -ItemType Directory -Path $feed -Force | Out-Null
if ($CleanFeed) { Remove-Item (Join-Path $feed '*.nupkg') -Force -ErrorAction SilentlyContinue }
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$versionCore = ($Version -split '-', 2)[0]
$versionParts = @($versionCore -split '\.')
if ($versionParts.Count -lt 3) { throw "Version must include major.minor.patch: $Version" }
$assemblyVersion = "$($versionParts[0]).$($versionParts[1]).0.0"
$fileVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2]).0"

$repoPaths = @($config.groups | ForEach-Object { $_.paths } | Where-Object { $_ -like 'packages/*' -or $_ -like 'event/Event.Streaming' -or $_ -like 'tools/KoreForge.Jex.Cli' -or $_ -like 'tools/KoreForge.Jex.LanguageServer' })
$pending = @()

foreach ($relativePath in $repoPaths) {
    $repo = Join-Path $root $relativePath
    if (-not (Test-Path $repo)) { continue }

    $packProjects = @(
        Get-ChildItem -Path $repo -Filter '*.csproj' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(bin|obj|tst|tests|test|benchmarks?)\\' } |
            Where-Object { $_.FullName -notmatch '\\(templates?|samples?)\\' } |
            Sort-Object FullName
    )
    if ($packProjects.Count -eq 0) { continue }

    foreach ($project in $packProjects) {
        $projectRelativePath = [System.IO.Path]::GetRelativePath($repo, $project.FullName)
        $pending += [pscustomobject]@{
            Repo = $repo
            RelativePath = $relativePath
            Project = $project
            ProjectRelativePath = $projectRelativePath
        }
    }
}

$failures = @{}
while ($pending.Count -gt 0) {
    $nextPending = @()
    $packedThisPass = 0

    foreach ($item in $pending) {
        Write-Host "Packing $($item.RelativePath)/$($item.ProjectRelativePath) ($Version)" -ForegroundColor Cyan
        $repoStaging = Join-Path $stagingRoot (($item.RelativePath -replace '[\\/]', '_'))
        $repoBuildRoot = Join-Path $artifactsRoot (Join-Path 'repos' (Join-Path (Split-Path $item.Repo -Leaf) 'build'))
        New-Item -ItemType Directory -Path $repoStaging -Force | Out-Null
        Push-Location $item.Repo
        try {
            & dotnet pack $item.Project.FullName -c $Configuration -o $repoStaging `
                --artifacts-path $repoBuildRoot `
                /p:MinVerSkip=true `
                /p:Version=$versionCore `
                /p:PackageVersion=$Version `
                /p:AssemblyVersion=$assemblyVersion `
                /p:FileVersion=$fileVersion
        }
        finally { Pop-Location }

        $key = "$($item.RelativePath)/$($item.ProjectRelativePath)"
        if ($LASTEXITCODE -ne 0) {
            $failures[$key] = "dotnet pack failed with exit code $LASTEXITCODE"
            $nextPending += $item
            continue
        }

        $packedThisPass++
        $failures.Remove($key)

        Get-ChildItem -Path $repoStaging -File -Filter '*.nupkg' |
            ForEach-Object { Copy-Item $_.FullName $feed -Force }
    }

    if ($packedThisPass -eq 0) {
        $failureList = $failures.GetEnumerator() | Sort-Object Name | ForEach-Object { " - $($_.Name): $($_.Value)" }
        throw "Unable to pack remaining projects:`n$($failureList -join [Environment]::NewLine)"
    }

    $pending = @($nextPending)
}

Write-Host "Local package feed ready: $feed" -ForegroundColor Green
Get-ChildItem $feed -Filter '*.nupkg' | Sort-Object Name | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
