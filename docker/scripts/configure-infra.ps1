[CmdletBinding()]
param(
    [string]$SaPassword = 'Streaming!Pass123'
)

$ErrorActionPreference = 'Stop'
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerDir   = Join-Path $scriptDir '..'
$redpanda    = 'streaming-redpanda'
$sqledge     = 'streaming-sqledge'

function Wait-ContainerReady {
    param(
        [string]$Name,
        [ScriptBlock]$Probe,
        [int]$TimeoutSeconds = 120
    )
    Write-Host "Waiting for '$Name'..."
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Probe) {
            Write-Host "  '$Name' is ready."
            return
        }
        Start-Sleep -Seconds 3
    }
    throw "Timed out waiting for '$Name'."
}

function Test-Redpanda {
    & docker exec $redpanda rpk cluster info *> $null
    return $LASTEXITCODE -eq 0
}

function Test-SqlEdge {
    & docker exec $sqledge /opt/mssql-tools/bin/sqlcmd `
        -S localhost -U sa -P $SaPassword -Q "SELECT 1" *> $null
    return $LASTEXITCODE -eq 0
}

# ── Wait for containers ───────────────────────────────────────────────────────
Wait-ContainerReady -Name $redpanda -Probe ${function:Test-Redpanda}
Wait-ContainerReady -Name $sqledge  -Probe ${function:Test-SqlEdge}

# ── SQL schema + seed ─────────────────────────────────────────────────────────
Write-Host 'Applying SQL schema (init.sql)...'
& docker exec $sqledge /opt/mssql-tools/bin/sqlcmd `
    -S localhost -U sa -P $SaPassword `
    -b `
    -i /docker-entrypoint-initdb.d/init.sql
if ($LASTEXITCODE -ne 0) { throw 'SQL init.sql failed.' }

Write-Host 'Inserting seed data (seed.sql)...'
& docker exec $sqledge /opt/mssql-tools/bin/sqlcmd `
    -S localhost -U sa -P $SaPassword `
    -b `
    -i /docker-entrypoint-initdb.d/seed.sql
if ($LASTEXITCODE -ne 0) { throw 'SQL seed.sql failed.' }

Write-Host 'Migrating old KafkaProcessor JEX extraction scripts...'
$repoRoot = Resolve-Path (Join-Path $dockerDir '..')
$oldExtractionSeed = Join-Path $repoRoot 'old_apps\KafkaProcessor\docker\sql\extraction_scripts_seed.sql'
if (Test-Path $oldExtractionSeed) {
    & docker cp $oldExtractionSeed "${sqledge}:/tmp/extraction_scripts_seed.sql"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to copy old extraction_scripts_seed.sql into SQL container.' }

    & docker exec $sqledge /opt/mssql-tools/bin/sqlcmd `
        -S localhost -U sa -P $SaPassword `
        -d StreamingPlatform `
        -b `
        -i /tmp/extraction_scripts_seed.sql
    if ($LASTEXITCODE -ne 0) { throw 'Old extraction_scripts_seed.sql migration failed.' }

    & docker exec $sqledge /opt/mssql-tools/bin/sqlcmd `
        -S localhost -U sa -P $SaPassword `
        -d StreamingPlatform `
        -b `
        -Q "UPDATE dbo.Scripts SET ApplicationId = 'EventReader' WHERE ApplicationId IN ('1', 'KafkaProcessor');"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to re-scope migrated scripts to EventReader.' }
}
else {
    Write-Host "  Old extraction seed not found at '$oldExtractionSeed'. Skipping."
}

# ── Kafka topics ──────────────────────────────────────────────────────────────
$topics = @(
    @{ Name = 'raw.events';         Partitions = 8 },
    @{ Name = 'raw.events.dlq';     Partitions = 4 },
    @{ Name = 'fraud.candidates';   Partitions = 8 },
    @{ Name = 'fraud.candidates.dlq'; Partitions = 4 },
    @{ Name = 'fraud.decisions';    Partitions = 8 },
    @{ Name = 'fraud.alerts';       Partitions = 4 },
    @{ Name = 'events.audit';       Partitions = 8 },
    @{ Name = 'events.archive';     Partitions = 8 }
)

$listOutput = & docker exec $redpanda rpk topic list 2>&1
foreach ($topic in $topics) {
    $exists = $listOutput | Where-Object { $_ -match "^$([regex]::Escape($topic.Name))\s" }
    if (-not $exists) {
        Write-Host "  Creating topic '$($topic.Name)' ($($topic.Partitions) partitions)..."
        & docker exec $redpanda rpk topic create $topic.Name -p $topic.Partitions
        if ($LASTEXITCODE -ne 0) { throw "Failed to create topic '$($topic.Name)'." }
    }
    else {
        Write-Host "  Topic '$($topic.Name)' already exists."
    }
}

Write-Host ''
Write-Host 'Infrastructure ready.'
Write-Host '  Redpanda Console : http://localhost:8081'
Write-Host '  SQL Edge         : localhost:14334  (sa / Streaming!Pass123 / db: StreamingPlatform)'
