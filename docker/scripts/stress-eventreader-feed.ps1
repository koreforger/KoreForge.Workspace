[CmdletBinding()]
param(
    [string]$Bootstrap = 'localhost:29092',
    [string]$Topic = 'raw.events',
    [int]$Count = 50000
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'publish-eventreader-sample.ps1') `
    -Bootstrap $Bootstrap `
    -Topic $Topic `
    -Count $Count `
    -DelayMs 0
