#!/usr/bin/env pwsh
# EventReader Stress Test
# Produces messages first, then runs EventReader, measures throughput
param(
    [int]$MessageCount = 2000000,
    [int]$TargetRatePerSec = 1000,
    [int]$ConsumerStartupWaitSec = 15,
    [int]$MeasurementWindowSec = 30
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path "$PSScriptRoot\..\.."

Write-Host "=== EventReader Pipeline Stress Test ===" -ForegroundColor Cyan
Write-Host "Strategy: Produce $MessageCount messages, then start reader, measure throughput"
Write-Host "Target: >= $TargetRatePerSec rec/sec over ${MeasurementWindowSec}s window"
Write-Host ""

# ── 1. Kill existing processes ─────────────────────────────────────
Write-Host "[1/7] Killing existing EventReader processes..." -ForegroundColor Yellow
Get-Process EventReader -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  Clean" -ForegroundColor Green

# ── 2. Check Docker ────────────────────────────────────────────────
Write-Host "[2/7] Checking Docker containers..." -ForegroundColor Yellow
$redpanda = docker ps --filter "name=streaming-redpanda" --format "{{.Status}}" 2>$null
if (-not $redpanda -or $redpanda -notmatch "healthy") {
    Write-Host "  Redpanda not healthy. Run: docker compose -f docker/docker-compose.yml up -d" -ForegroundColor Red
    exit 1
}
Write-Host "  Redpanda: healthy" -ForegroundColor Green

$sql = docker ps --filter "name=streaming-sqledge" --format "{{.Status}}" 2>$null
if (-not $sql -or $sql -notmatch "healthy") {
    Write-Host "  SQL Edge not healthy." -ForegroundColor Red
    exit 1
}
Write-Host "  SQL Edge: healthy" -ForegroundColor Green

# ── 3. Configure Kafka SQL settings ─────────────────────────────────
Write-Host "[3/8] Configuring Kafka settings (latest offset, fresh consumer group)..." -ForegroundColor Yellow
$groupId = "stress-reader-$(Get-Date -Format 'HHmmss')"
docker exec streaming-sqledge /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Streaming!Pass123' -d StreamingPlatform -Q "SET QUOTED_IDENTIFIER ON; UPDATE dbo.Settings SET [Value]='latest' WHERE ApplicationId='EventReader' AND [Key]='Kafka:Profiles:Default:ConfluentOptions:auto.offset.reset'; UPDATE dbo.Settings SET [Value]='$groupId' WHERE ApplicationId='EventReader' AND [Key]='Kafka:Profiles:Default:ConfluentOptions:group.id';" 2>&1 | Out-Null
Write-Host "  Group=$groupId, offset=latest" -ForegroundColor Green

# ── 4. Build EventReader ───────────────────────────────────────────
Write-Host "[4/8] Building EventReader..." -ForegroundColor Yellow
dotnet build "$repoRoot/apps/EventReader/src/EventReader/EventReader.csproj" -c Release --nologo 2>&1 | Select-String "Build succeeded|error CS" | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -ne 0) { Write-Host "  ERROR: Build failed" -ForegroundColor Red; exit 1 }

# ── 5. Start EventReader ───────────────────────────────────────────
Write-Host "[5/8] Starting EventReader..." -ForegroundColor Yellow

$env:KOREFORGE_SETTINGS_CONNECTIONSTRING = "Server=localhost,14334;Database=StreamingPlatform;User Id=sa;Password=Streaming!Pass123;TrustServerCertificate=true;"
$env:ASPNETCORE_URLS = "http://localhost:0"
$stdoutLog = "$env:TEMP\eventreader-stress-stdout.txt"
$stderrLog = "$env:TEMP\eventreader-stress-stderr.txt"

$proc = Start-Process -FilePath "dotnet" `
    -ArgumentList "run --project `"$repoRoot/apps/EventReader/src/EventReader/EventReader.csproj`" -c Release --no-build" `
    -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

Write-Host "  PID: $($proc.Id), waiting ${ConsumerStartupWaitSec}s for consumer startup..." -ForegroundColor Yellow
Start-Sleep -Seconds $ConsumerStartupWaitSec

if ($proc.HasExited) {
    Write-Host "  ERROR: App crashed on startup:" -ForegroundColor Red
    Get-Content $stderrLog -Tail 15
    exit 1
}
Write-Host "  Consumer started" -ForegroundColor Green

# ── 6. Produce messages ────────────────────────────────────────────
Write-Host "[6/8] Producing $MessageCount messages to raw.events..." -ForegroundColor Yellow
$produceStart = Get-Date
$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    $sw = [System.IO.StreamWriter]::new($tmpFile)
    for ($i = 0; $i -lt $MessageCount; $i++) {
        $msg = "{""Action"":""payment.created"",""eventId"":""evt-$i"",""NedbankID"":""$((10000 + $i % 50000))"",""amount"":$($i % 1000),""Channel"":""web"",""SessionId"":""sess-$i""}"
        $sw.WriteLine($msg)
        if ($i % 100000 -eq 0 -and $i -gt 0) {
            Write-Host "  Wrote $i / $MessageCount ($([math]::Round($i/$MessageCount*100,1))%)"
        }
    }
    $sw.Close()
    Get-Content $tmpFile | docker exec -i streaming-redpanda rpk topic produce raw.events --brokers localhost:9092 -f '%v' 2>&1 | Out-Null
} finally {
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
}
$produceElapsed = ((Get-Date) - $produceStart).TotalSeconds
Write-Host "  Produced $MessageCount messages in $([math]::Round($produceElapsed, 1))s ($([math]::Round($MessageCount/$produceElapsed, 0)) msg/sec)" -ForegroundColor Green

# ── 7. Measure throughput ──────────────────────────────────────────
Write-Host "[7/8] Measuring throughput for ${MeasurementWindowSec}s..." -ForegroundColor Yellow
$measureStart = Get-Date
$rateSamples = @()
$lastClassified = 0

for ($i = 5; $i -le $MeasurementWindowSec; $i += 5) {
    Start-Sleep -Seconds 5
    if ($proc.HasExited) { Write-Host "  WARNING: Process exited" -ForegroundColor Yellow; break }
    
    $log = Get-Content $stdoutLog -Tail 200 -ErrorAction SilentlyContinue
    $classified = ($log | Select-String -Pattern "classified and enqueued" | Measure-Object).Count
    $processed = ($log | Select-String -Pattern "Worker.*processed item" | Measure-Object).Count
    $completed = ($log | Select-String -Pattern "Completed|output publisher" | Measure-Object).Count
    
    $delta = $classified - $lastClassified
    $lastClassified = $classified
    $instantRate = [math]::Round($delta / 5.0, 0)
    $overallRate = [math]::Round($classified / $i, 0)
    
    $rateSamples += $overallRate
    Write-Host "  [+${i}s] Classified=$classified Processed=$processed Completed=$completed Rate=$overallRate/sec (instant=$instantRate/sec)" -ForegroundColor Cyan
}

$measureElapsed = ((Get-Date) - $measureStart).TotalSeconds

# ── 7. Stop and report ─────────────────────────────────────────────
Write-Host "[8/8] Stopping and calculating results..." -ForegroundColor Yellow

$proc.Kill()
Start-Sleep -Seconds 2

$finalLog = Get-Content $stdoutLog -ErrorAction SilentlyContinue
$stderrContent = Get-Content $stderrLog -ErrorAction SilentlyContinue

$totalClassified = ($finalLog | Select-String -Pattern "classified and enqueued" | Measure-Object).Count
$totalProcessed = ($finalLog | Select-String -Pattern "Worker.*processed item" | Measure-Object).Count
$totalPublish = ($finalLog | Select-String -Pattern "Output publish" | Measure-Object).Count
$warnings = ($finalLog + $stderrContent | Select-String -Pattern "not mapped|NoDiscriminator|NoMatch|EmptyPayload|InvalidJson" | Measure-Object).Count
$errors = ($finalLog + $stderrContent | Select-String -Pattern "error|fail|Error|Fail|exception|Exception" | Measure-Object).Count

$avgRate = if ($measureElapsed -gt 0) { [math]::Round($totalClassified / $measureElapsed, 1) } else { 0 }
$avgSampleRate = if ($rateSamples.Count -gt 0) { [math]::Round(($rateSamples | Measure-Object -Average).Average, 1) } else { 0 }
$peakRate = if ($rateSamples.Count -gt 0) { [math]::Round(($rateSamples | Measure-Object -Maximum).Maximum, 1) } else { 0 }

# Cleanup log files (keep if debugging)
# Remove-Item $stdoutLog -Force -ErrorAction SilentlyContinue
# Remove-Item $stderrLog -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  STRESS TEST RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Messages produced:    $MessageCount" -ForegroundColor White
Write-Host "  Produce time:         $([math]::Round($produceElapsed, 1))s" -ForegroundColor White
Write-Host "  Measure window:       $([math]::Round($measureElapsed, 1))s" -ForegroundColor White
Write-Host "  Classified:           $totalClassified" -ForegroundColor White
Write-Host "  Processed (workers):  $totalProcessed" -ForegroundColor White
Write-Host "  Published (output):   $totalPublish" -ForegroundColor White
Write-Host "  Warnings:             $warnings" -ForegroundColor White
Write-Host "  Errors:               $errors" -ForegroundColor $(if ($errors -gt 100) { 'Yellow' } elseif ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host "  ---" -ForegroundColor White
Write-Host "  Avg throughput:       $avgRate rec/sec (instant avg: $avgSampleRate)" -ForegroundColor $(if ($avgRate -ge $TargetRatePerSec) { 'Green' } else { 'Red' })
Write-Host "  Peak throughput:      $peakRate rec/sec" -ForegroundColor Yellow
Write-Host "  Target:               $TargetRatePerSec rec/sec" -ForegroundColor White
Write-Host "  Status:               $(if ($avgRate -ge $TargetRatePerSec) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($avgRate -ge $TargetRatePerSec) { 'Green' } else { 'Red' })

if ($avgRate -ge $TargetRatePerSec) {
    Write-Host "`nStress test PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nStress test FAILED — below target. Check log patterns above for bottlenecks." -ForegroundColor Red
    exit 1
}
