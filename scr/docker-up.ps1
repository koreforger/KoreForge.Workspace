#Requires -Version 7.2
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $root 'docker/docker-compose.yml'
if (-not (Test-Path $compose)) { throw "Missing compose file: $compose" }

Push-Location $root
try {
    docker compose -f $compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed with exit code $LASTEXITCODE" }
    if (Test-Path (Join-Path $root 'docker/scripts/configure-infra.ps1')) {
        & (Join-Path $root 'docker/scripts/configure-infra.ps1')
    }
}
finally { Pop-Location }
