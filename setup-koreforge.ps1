#Requires -Version 7.2
<#+
.SYNOPSIS
    Sets up a KoreForge workspace clone.

.DESCRIPTION
    This script is the new-user entry point for the workspace shell. It verifies core tools,
    prepares local ignored folders, and can clone the repo set once the GitHub repo map is final.
#>
[CmdletBinding()]
param(
    [string]$Root = $PSScriptRoot,
    [string]$GitHubOwner = 'koreforger',
    [switch]$CloneMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootPath = (Resolve-Path $Root).Path

function Require-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Require-Command pwsh
Require-Command dotnet
Require-Command git

$localFolders = @(
    (Join-Path $rootPath '.artifacts/packages'),
    (Join-Path $rootPath '.artifacts/script-runner/logs'),
    (Join-Path $rootPath '.local/secrets')
)

New-Item -ItemType Directory -Path $localFolders -Force | Out-Null

$configPath = Join-Path $rootPath 'builder-v5.config.json'
if (-not (Test-Path $configPath)) {
    throw "Missing builder manifest: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$repoPaths = @($config.groups | ForEach-Object { $_.paths } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($CloneMissing) {
    Require-Command gh
    foreach ($path in $repoPaths) {
        $target = Join-Path $rootPath $path
        if (Test-Path $target) { continue }

        $repoName = Split-Path $path -Leaf
        $repoUrl = "https://github.com/$GitHubOwner/$repoName.git"
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        git clone $repoUrl $target
        if ($LASTEXITCODE -ne 0) { throw "Failed to clone $repoUrl" }
    }
}

Write-Host "KoreForge workspace ready: $rootPath" -ForegroundColor Green
Write-Host "Local NuGet feed: $((Join-Path $rootPath '.artifacts/packages'))" -ForegroundColor Cyan
Write-Host "Run .\builder-v5.ps1 to build, test, pack, or release repos." -ForegroundColor Cyan
