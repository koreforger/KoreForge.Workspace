<#
.SYNOPSIS
    Decodes artifacts/zips/Information.zip back to the original zip file,
    saved as artifacts/zips/Original.KoreForge.zip.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root    = Split-Path $PSScriptRoot -Parent
$zipsDir = Join-Path $root 'artifacts\zips'
$infoZip = Join-Path $zipsDir 'Information.zip'

if (-not (Test-Path $infoZip)) { throw "Information.zip not found at $infoZip" }
Write-Host "Source : $infoZip"

# 1. Open Information.zip and read Information.txt
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream  = [System.IO.File]::OpenRead($infoZip)
$archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Read)
$entry   = $archive.GetEntry('Information.txt')
if (-not $entry) { $archive.Dispose(); $stream.Dispose(); throw "Information.txt not found inside Information.zip" }
$reader   = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::ASCII)
$reversed = $reader.ReadToEnd()
$reader.Dispose()
$archive.Dispose()
$stream.Dispose()
Write-Host "Read    : $($reversed.Length) chars from Information.txt"

# 2. Reverse the string to recover Base64
$encoded = -join $reversed[-1..-($reversed.Length)]

# 3. Base64-decode back to original bytes
$bytes = [System.Convert]::FromBase64String($encoded)

# 4. Write as Original.KoreForge.zip
$outZip = Join-Path $zipsDir 'Original.KoreForge.zip'
[System.IO.File]::WriteAllBytes($outZip, $bytes)

Write-Host "Output  : $outZip  ($([math]::Round($bytes.Length/1MB,2)) MB)"
Write-Host "✓ Original.KoreForge.zip restored."
