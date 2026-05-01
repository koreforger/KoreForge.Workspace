[CmdletBinding()]
param(
    [string]$Bootstrap = 'localhost:29092',
    [string]$Topic = 'raw.events',
    [int]$Count = 100,
    [int]$DelayMs = 50
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$publisherProject = Join-Path $repoRoot 'old_apps\KafkaProcessor\tools\TestPublisher\TestPublisher.csproj'

dotnet run --project $publisherProject -- `
    --bootstrap $Bootstrap `
    --topic $Topic `
    --count $Count `
    --delay-ms $DelayMs
