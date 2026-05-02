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
$configPath = Join-Path $root 'builder.config.json'
if (-not (Test-Path $configPath)) { throw "Missing builder manifest: $configPath" }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$artifactsRoot = Join-Path $root $(if ($config.artifactsRoot) { $config.artifactsRoot } else { 'artifacts' })
$feed = Join-Path $root $config.localPackageFeed
$stagingRoot = Join-Path $artifactsRoot 'packages/staging'
$nugetPackagesRoot = Join-Path $artifactsRoot 'nuget-cache'
New-Item -ItemType Directory -Path $feed -Force | Out-Null
New-Item -ItemType Directory -Path $nugetPackagesRoot -Force | Out-Null
if ($CleanFeed) {
    Remove-Item (Join-Path $feed '*.nupkg') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $nugetPackagesRoot 'koreforge.*') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $nugetPackagesRoot 'event.*') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $nugetPackagesRoot 'monitoringregistry') -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$env:NUGET_PACKAGES = $nugetPackagesRoot
$env:NO_COLOR = '1'   # suppress ANSI sequences in dotnet and child process output

function Get-ProjectPropertyValue {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$Project,

        [Parameter(Mandatory)]
        [string]$Name
    )

    [xml]$projectXml = Get-Content $Project.FullName -Raw
    foreach ($propertyGroup in @($projectXml.Project.PropertyGroup)) {
        $property = @($propertyGroup.ChildNodes | Where-Object { $_.LocalName -eq $Name } | Select-Object -First 1)
        if ($property.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($property[0].InnerText)) {
            return $property[0].InnerText
        }
    }

    return $null
}

function Get-InternalPackageReferences {
    param([Parameter(Mandatory)][System.IO.FileInfo]$Project)
    try {
        [xml]$xml = Get-Content $Project.FullName -Raw
        @($xml.Project.ItemGroup | ForEach-Object { $_.ChildNodes } |
            Where-Object { $null -ne $_ -and $_.LocalName -eq 'PackageReference' } |
            ForEach-Object { $_.GetAttribute('Include') } |
            Where-Object { $_ })
    }
    catch { @() }
}

function Get-TopologicallySortedItems {
    param([Parameter(Mandatory)][object[]]$Items)

    $byId    = @{}
    foreach ($item in $Items) { $byId[$item.PackageId] = $item }

    $inDegree = @{}
    $rdeps    = @{}
    foreach ($pkgId in $byId.Keys) {
        $inDegree[$pkgId] = 0
        $rdeps[$pkgId]    = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($item in $Items) {
        $refs = Get-InternalPackageReferences -Project $item.Project
        foreach ($ref in $refs) {
            if ($byId.ContainsKey($ref)) {
                $inDegree[$item.PackageId]++
                $rdeps[$ref].Add($item.PackageId)
            }
        }
    }

    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($pkgId in ($inDegree.Keys | Sort-Object)) {
        if ($inDegree[$pkgId] -eq 0) { $queue.Enqueue($pkgId) }
    }

    $sorted = [System.Collections.Generic.List[object]]::new()
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $sorted.Add($byId[$current])
        foreach ($dep in ($rdeps[$current] | Sort-Object)) {
            $inDegree[$dep]--
            if ($inDegree[$dep] -eq 0) { $queue.Enqueue($dep) }
        }
    }

    if ($sorted.Count -ne $Items.Count) {
        $cycle = $inDegree.GetEnumerator() | Where-Object { $_.Value -gt 0 } | ForEach-Object { $_.Key }
        throw "Cyclic dependency detected among packages: $($cycle -join ', ')"
    }

    $sorted.ToArray()
}

$versionCore = ($Version -split '-', 2)[0]
$versionParts = @($versionCore -split '\.')
if ($versionParts.Count -lt 3) { throw "Version must include major.minor.patch: $Version" }
$assemblyVersion = "$($versionParts[0]).$($versionParts[1]).0.0"
$fileVersion = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2]).0"

$repoPaths = @($config.groups | ForEach-Object { $_.paths } | Where-Object { $_ -like 'eco-system/*' -or $_ -like 'event/Event.Streaming' -or $_ -like 'tools/KoreForge.Jex.Cli' -or $_ -like 'tools/KoreForge.Jex.LanguageServer' })
$pending = @()

foreach ($relativePath in $repoPaths) {
    $repo = Join-Path $root $relativePath
    if (-not (Test-Path $repo)) { continue }

    $packProjects = @(
        Get-ChildItem -Path $repo -Filter '*.csproj' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(bin|obj|benchmarks?)\\' } |
            Where-Object { $_.FullName -notmatch '\\(templates?|samples?)\\' } |
            Sort-Object FullName
    )
    if ($packProjects.Count -eq 0) { continue }

    foreach ($project in $packProjects) {
        $isPackable = Get-ProjectPropertyValue -Project $project -Name 'IsPackable'
        if ($null -ne $isPackable -and $isPackable.Trim().Equals('false', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $packageId = Get-ProjectPropertyValue -Project $project -Name 'PackageId'
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $packageId = Get-ProjectPropertyValue -Project $project -Name 'AssemblyName'
        }
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $packageId = [System.IO.Path]::GetFileNameWithoutExtension($project.Name)
        }

        $projectRelativePath = [System.IO.Path]::GetRelativePath($repo, $project.FullName)
        $pending += [pscustomobject]@{
            Repo = $repo
            RelativePath = $relativePath
            Project = $project
            ProjectRelativePath = $projectRelativePath
            PackageId = $packageId
        }
    }
}

$pending = @(Get-TopologicallySortedItems -Items $pending)

foreach ($item in $pending) {
    Write-Host "Packing $($item.RelativePath)/$($item.ProjectRelativePath) ($Version)" -ForegroundColor Cyan
    $repoStaging = Join-Path $stagingRoot (($item.RelativePath -replace '[\\/]', '_'))
    $repoBuildRoot = Join-Path $artifactsRoot (Join-Path 'repos' (Join-Path (Split-Path $item.Repo -Leaf) 'build'))
    $repoComponentBinRoot = Join-Path $repoBuildRoot 'bin'
    $artifactsConfiguration = $Configuration.ToLowerInvariant()
    New-Item -ItemType Directory -Path $repoStaging -Force | Out-Null
    Push-Location $item.Repo
    try {
        & dotnet pack $item.Project.FullName -c $Configuration -o $repoStaging `
            --artifacts-path $repoBuildRoot `
            /p:MinVerSkip=true `
            /p:Version=$versionCore `
            /p:PackageVersion=$Version `
            /p:AssemblyVersion=$assemblyVersion `
            /p:FileVersion=$fileVersion `
            /p:RestoreNoCache=true `
            /p:KoreForgeComponentBinRoot=$repoComponentBinRoot `
            /p:KoreForgeArtifactsConfiguration=$artifactsConfiguration
    }
    finally { Pop-Location }

    if ($LASTEXITCODE -ne 0) {
        throw "dotnet pack failed for $($item.PackageId) (exit $LASTEXITCODE)"
    }

    $expectedPackage = Join-Path $repoStaging "$($item.PackageId).$Version.nupkg"
    if (-not (Test-Path $expectedPackage)) {
        throw "dotnet pack succeeded but did not produce $($item.PackageId).$Version.nupkg"
    }

    Get-Item -Path $expectedPackage | ForEach-Object { Copy-Item $_.FullName $feed -Force }
}

Write-Host "Local package feed ready: $feed" -ForegroundColor Green
Get-ChildItem $feed -Filter '*.nupkg' | Sort-Object Name | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
