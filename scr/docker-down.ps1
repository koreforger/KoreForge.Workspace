#Requires -Version 7.2
[CmdletBinding()]
param([switch]$Volumes)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $root 'docker/docker-compose.yml'
if (-not (Test-Path $compose)) { throw "Missing compose file: $compose" }

$args = @('compose', '-f', $compose, 'down')
if ($Volumes) { $args += '--volumes' }

Push-Location $root
try {
    docker @args
    if ($LASTEXITCODE -ne 0) { throw "docker compose down failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }
