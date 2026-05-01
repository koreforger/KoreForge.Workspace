#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Version = '1.0.1-alpha',
    [switch]$CleanFeed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $root 'builder-v5.config.json'
if (-not (Test-Path $configPath)) { throw "Missing builder manifest: $configPath" }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$feed = Join-Path $root $config.localPackageFeed
New-Item -ItemType Directory -Path $feed -Force | Out-Null
if ($CleanFeed) { Remove-Item (Join-Path $feed '*.nupkg') -Force -ErrorAction SilentlyContinue }

$repoPaths = @($config.groups | ForEach-Object { $_.paths } | Where-Object { $_ -like 'packages/*' -or $_ -like 'event/Event.Streaming' -or $_ -like 'tools/KoreForge.Jex.Cli' -or $_ -like 'tools/KoreForge.Jex.LanguageServer' })

foreach ($relativePath in $repoPaths) {
    $repo = Join-Path $root $relativePath
    $packScript = Join-Path $repo 'scr/build-pack.ps1'
    if (-not (Test-Path $packScript)) { continue }

    Write-Host "Packing $relativePath ($Version)" -ForegroundColor Cyan
    & $packScript -Version $Version
    if ($LASTEXITCODE -ne 0) { throw "Pack failed: $relativePath" }

    Get-ChildItem -Path $repo -Recurse -File -Filter '*.nupkg' |
        Where-Object { $_.FullName -match '\\artifacts\\|\\out\\|\\.artifacts\\' } |
        ForEach-Object { Copy-Item $_.FullName $feed -Force }
}

Write-Host "Local package feed ready: $feed" -ForegroundColor Green
Get-ChildItem $feed -Filter '*.nupkg' | Sort-Object Name | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
