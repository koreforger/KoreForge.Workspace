#Requires -Version 7.2
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
& (Join-Path $root 'scr/docker-down.ps1') -Volumes
& (Join-Path $root 'scr/docker-up.ps1')
