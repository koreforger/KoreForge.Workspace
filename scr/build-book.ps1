#Requires -Version 7.2
<#
.SYNOPSIS
    Generates the KoreForge Ecosystem Reference PDF book.
.DESCRIPTION
    Compiles all workspace documentation into a single professionally-typeset PDF.
    Uses the KoreForge.DocBook dotnet tool (Markdig + QuestPDF — no additional
    software installation required beyond the .NET SDK).
.PARAMETER OutputPath
    Destination for the generated PDF.
    Defaults to artifacts/KoreForge-Reference.pdf.
#>
[CmdletBinding()]
param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'artifacts\KoreForge-Reference.pdf'
}

$toolProject = Join-Path $root 'tools\KoreForge.DocBook\src\KoreForge.DocBook\KoreForge.DocBook.csproj'

if (-not (Test-Path $toolProject)) {
    Write-Error "DocBook tool not found: $toolProject"
}

New-Item -ItemType Directory -Path (Split-Path $OutputPath) -Force | Out-Null

Write-Host ''
Write-Host '══ KoreForge Ecosystem Reference ══════════════════════' -ForegroundColor Cyan
Write-Host "   Output: $OutputPath" -ForegroundColor DarkGray
Write-Host ''

dotnet run `
    --project $toolProject `
    --configuration Release `
    -- `
    $root `
    $OutputPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "Book generation failed (exit $LASTEXITCODE)"
}

Write-Host ''
Write-Host '══════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host "  Book generated: $OutputPath" -ForegroundColor Green
Write-Host '══════════════════════════════════════════════════════' -ForegroundColor Cyan
