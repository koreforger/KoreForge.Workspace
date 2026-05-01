<#
.SYNOPSIS
    Translates a datetime to Kafka offsets for all partitions of a topic.
    Useful for setting a replay start/stop position in EventReader or EventProcessor.

.DESCRIPTION
    Queries Redpanda (via rpk) to find the offset corresponding to a given UTC timestamp
    on each partition of a topic. Prints the offset-per-partition table and emits a
    single-line SQL snippet you can paste into the Settings table.

.PARAMETER Topic
    Kafka topic name (e.g. 'raw.events').

.PARAMETER Timestamp
    UTC datetime string, e.g. '2026-04-27T10:00:00Z' or '2026-04-27 10:00:00'.
    Accepts any format parseable by [datetime]::Parse.

.PARAMETER Broker
    Kafka bootstrap server. Default: localhost:29092

.EXAMPLE
    .\find-offset-for-datetime.ps1 -Topic raw.events -Timestamp '2026-04-27T10:00:00Z'

.EXAMPLE
    # Find the range for "10am to 11am"
    .\find-offset-for-datetime.ps1 -Topic raw.events -Timestamp '2026-04-27T10:00:00Z'
    .\find-offset-for-datetime.ps1 -Topic raw.events -Timestamp '2026-04-27T11:00:00Z'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Topic,
    [Parameter(Mandatory)][string]$Timestamp,
    [string]$Broker = 'localhost:29092'
)

$ErrorActionPreference = 'Stop'
$redpanda = 'streaming-redpanda'

# Parse and convert to Unix milliseconds
$dt = [datetime]::Parse($Timestamp, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
$epoch = [datetime]'1970-01-01T00:00:00Z'
$epochMs = [long](($dt - $epoch).TotalMilliseconds)

Write-Host "Topic     : $Topic"
Write-Host "Timestamp : $($dt.ToString('yyyy-MM-ddTHH:mm:ssZ')) UTC"
Write-Host "Epoch ms  : $epochMs"
Write-Host ""

# Ask rpk for offsets at that timestamp
$raw = & docker exec $redpanda rpk topic seek $Topic --timestamp $epochMs 2>&1

if ($LASTEXITCODE -ne 0) {
    # rpk topic seek may not be available in all versions — fall back to list-offsets
    Write-Warning "rpk topic seek returned non-zero. Falling back to manual partition listing."
    $partitionList = & docker exec $redpanda rpk topic describe $Topic 2>&1
    Write-Host $partitionList
    Write-Host ""
    Write-Host "NOTE: Automatic offset lookup requires Redpanda >= v23 with 'rpk topic seek'."
    Write-Host "If unavailable, use the Redpanda Console at http://localhost:8081 to find the offset manually."
    exit 1
}

Write-Host "Offset results from Redpanda:"
Write-Host $raw
Write-Host ""

# Parse output — rpk topic seek typically outputs: PARTITION  OFFSET
$results = $raw | Select-String '^\s*(\d+)\s+(\d+)' | ForEach-Object {
    [pscustomobject]@{
        Partition = [int]$_.Matches[0].Groups[1].Value
        Offset    = [long]$_.Matches[0].Groups[2].Value
    }
}

if ($results.Count -eq 0) {
    Write-Warning "Could not parse offset results. Check output above."
    exit 1
}

$results | Format-Table -AutoSize

# The minimum offset across all partitions is a safe single-value approximation
$minOffset = ($results | Measure-Object -Property Offset -Minimum).Minimum
$maxOffset = ($results | Measure-Object -Property Offset -Maximum).Maximum

Write-Host "Minimum offset across all partitions : $minOffset"
Write-Host "Maximum offset across all partitions : $maxOffset"
Write-Host ""
Write-Host "── SQL snippet to configure EventReader seek ──────────────────────────────"
Write-Host "UPDATE dbo.Settings"
Write-Host "   SET [Value] = 'FromTimestamp', ModifiedBy = 'manual', ModifiedDate = SYSUTCDATETIME()"
Write-Host " WHERE ApplicationId = 'EventReader' AND [Key] = 'EventReader:Seek:Mode';"
Write-Host ""
Write-Host "UPDATE dbo.Settings"
Write-Host "   SET [Value] = '$($dt.ToString('yyyy-MM-ddTHH:mm:ssZ'))', ModifiedBy = 'manual', ModifiedDate = SYSUTCDATETIME()"
Write-Host " WHERE ApplicationId = 'EventReader' AND [Key] = 'EventReader:Seek:StartOffsetOrTimestamp';"
Write-Host "────────────────────────────────────────────────────────────────────────────"
