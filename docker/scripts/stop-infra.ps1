[CmdletBinding()]
param(
    [switch]$Wipe
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerDir = Join-Path $scriptDir '..'

Push-Location $dockerDir
try {
    if ($Wipe) {
        Write-Host 'Stopping and removing containers + volumes...'
        docker compose down -v
    }
    else {
        Write-Host 'Stopping containers (data volumes preserved)...'
        docker compose down
    }
    Write-Host 'Done.'
}
finally {
    Pop-Location
}
