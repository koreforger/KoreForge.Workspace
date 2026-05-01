[CmdletBinding()]
param(
    [string]$Bootstrap = 'localhost:29092',
    [string]$Topic = 'raw.events',
    [int]$RatePerSecond = 10,
    [int]$BatchSize = 1000
)

$ErrorActionPreference = 'Stop'
$delayMs = if ($RatePerSecond -le 0) { 0 } else { [Math]::Max(0, [Math]::Round(1000 / $RatePerSecond)) }

Write-Host "Continuous EventReader feed"
Write-Host "  Bootstrap : $Bootstrap"
Write-Host "  Topic     : $Topic"
Write-Host "  Rate      : ~$RatePerSecond msg/s"
Write-Host "  BatchSize : $BatchSize"
Write-Host "  Stop with Ctrl+C"
Write-Host ''

while ($true) {
    & (Join-Path $PSScriptRoot 'publish-eventreader-sample.ps1') `
        -Bootstrap $Bootstrap `
        -Topic $Topic `
        -Count $BatchSize `
        -DelayMs $delayMs
}
