<#
.SYNOPSIS
    Encodes the latest KoreForge compact zip into a reversed Base64 text file,
    then packages it as artifacts/zips/Information.zip containing Information.txt.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root      = Split-Path $PSScriptRoot -Parent
$zipsDir   = Join-Path $root 'artifacts\zips'

# Find the latest compact zip
$sourceZip = Get-ChildItem (Join-Path $zipsDir 'KoreForge-compact-*.zip') |
             Sort-Object LastWriteTime |
             Select-Object -Last 1

if (-not $sourceZip) { throw "No KoreForge-compact-*.zip found in $zipsDir" }
Write-Host "Source : $($sourceZip.FullName)"

# 1. Read bytes
$bytes = [System.IO.File]::ReadAllBytes($sourceZip.FullName)

# 2. Base64-encode (uuencode equivalent)
$encoded = [System.Convert]::ToBase64String($bytes)

# 3. Reverse the string
$reversed = -join $encoded[-1..-($encoded.Length)]

# 4. Write as Information.txt to a temp location
$tempTxt = Join-Path $env:TEMP 'Information.txt'
[System.IO.File]::WriteAllText($tempTxt, $reversed, [System.Text.Encoding]::ASCII)
Write-Host "Encoded : $($reversed.Length) chars -> $tempTxt"

# 5. Zip into Information.zip (ZipArchive — add only Information.txt)
$outZip = Join-Path $zipsDir 'Information.zip'
if (Test-Path $outZip) { Remove-Item $outZip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream  = [System.IO.File]::Open($outZip, [System.IO.FileMode]::Create)
$archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
$entry   = $archive.CreateEntry('Information.txt', [System.IO.Compression.CompressionLevel]::Optimal)
$entryStream = $entry.Open()
$txtBytes    = [System.Text.Encoding]::ASCII.GetBytes($reversed)
$entryStream.Write($txtBytes, 0, $txtBytes.Length)
$entryStream.Dispose()
$archive.Dispose()
$stream.Dispose()

Write-Host "Output  : $outZip"
Write-Host "✓ Information.zip created."
