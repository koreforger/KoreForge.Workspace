[CmdletBinding()]
param(
    [int]$UiPort = 5174,
    [int]$ApiPort = 5282,
    [int]$FeedRatePerSecond = 10,
    [switch]$SkipInfra
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$apiUrl = "http://localhost:$ApiPort"
$uiUrl = "http://127.0.0.1:$UiPort"

if (-not $SkipInfra) {
    & (Join-Path $PSScriptRoot 'start-infra.ps1')
    & (Join-Path $PSScriptRoot 'configure-infra.ps1')
}

Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$repoRoot'; `$env:ASPNETCORE_URLS='$apiUrl'; dotnet run --project apps\EventReader\src\EventReader\EventReader.csproj --urls $apiUrl"
)

Start-Sleep -Seconds 3

Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$repoRoot\apps\EventAdminUI'; `$env:EVENT_READER_URL='$apiUrl'; npm run dev -- --port $UiPort"
)

Start-Sleep -Seconds 3

Start-Process powershell -ArgumentList @(
    '-NoExit',
    '-Command',
    "Set-Location '$repoRoot'; .\docker\scripts\start-eventreader-feed.ps1 -RatePerSecond $FeedRatePerSecond"
)

Start-Sleep -Seconds 2
Start-Process $uiUrl

Write-Host "EventReader system launched."
Write-Host "  API  : $apiUrl"
Write-Host "  UI   : $uiUrl"
Write-Host "  Feed : $FeedRatePerSecond msg/s into raw.events"
