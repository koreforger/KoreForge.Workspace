[CmdletBinding()]
param(
    [switch]$Wipe
)

$ErrorActionPreference = 'Stop'
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerDir  = Join-Path $scriptDir '..'

Push-Location $dockerDir
try {
    if ($Wipe) {
        Write-Host 'Wiping all data volumes (docker compose down -v)...'
        docker compose down -v
    }

    Write-Host 'Starting Redpanda + SQL Edge + Console...'
    docker compose up -d redpanda sqledge console
    docker compose ps

    Write-Host ''
    Write-Host 'Services starting. Run configure-infra.ps1 to initialize topics and SQL schema.'
    Write-Host 'Redpanda Console : http://localhost:8081'
    Write-Host 'SQL Edge         : localhost:14334 (sa / Streaming!Pass123)'
}
finally {
    Pop-Location
}
