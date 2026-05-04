#Requires -Version 7.2
<#
.SYNOPSIS
    KoreForge interactive script runner.

.DESCRIPTION
    Presents a console GUI menu of all runnable scripts found across every
    KoreForge repository under $Root (scanned up to 2 levels deep), plus a
    "System" section at the top for workspace-level scripts in $Root/scr/.

    SYSTEM SCRIPTS ($Root/scr/*.ps1)
        Listed first, under a ── SYSTEM ── header.  These are workspace-level
        orchestrators such as:
          • release-nuget-from-local  — update deps, pack, push to NuGet.org
          • release-nuget-from-github — update deps, commit, tag, push to GitHub Actions
          • pack-all                  — pack all repos without publishing

    REPO SCRIPTS (per-repo scr/*.ps1)
        Standard scripts (build-clean, build-rebuild, build-test, …) are
        discovered by matching known action names to fixed script filenames.
        Stress scripts are discovered automatically: any file matching
        run-stress-*.ps1 appears as a "Stress: <Name>" action.

    After a run the script offers to open any test/coverage/stress HTML reports.
    Stress scripts must print a line of the form:
        Stress report: <absolute-or-relative-path>
    so the runner can locate the output file.

    System scripts that accept -Version receive the version entered at the
    selection prompt when one of them is selected.

.PARAMETER Root
    Root folder to scan.  Defaults to the directory containing this script.

.PARAMETER Configuration
    Default build configuration (Debug or Release).
#>

[CmdletBinding()]
param(
    [string] $Root = $PSScriptRoot,

    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Debug"
)

$ErrorActionPreference = "Stop"

$moduleName = "Microsoft.PowerShell.ConsoleGuiTools"

if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "Installing module: $moduleName" -ForegroundColor Yellow
    Install-Module $moduleName -Scope CurrentUser -Force -AllowClobber
}

Import-Module $moduleName -ErrorAction Stop

# ---------------------------------------------------------------------------
# Standard repo actions — fixed script names matched per repo
# ---------------------------------------------------------------------------
$standardActions = @(
    [pscustomobject]@{ Action = "Clean";       Order = 10; Script = "build-clean.ps1";             Description = "Clean this repository's build and artifact outputs." }
    [pscustomobject]@{ Action = "Rebuild";     Order = 20; Script = "build-rebuild.ps1";           Description = "Restore and rebuild this repository from a clean state." }
    [pscustomobject]@{ Action = "Test";        Order = 30; Script = "build-test.ps1";              Description = "Build and run this repository's unit tests." }
    [pscustomobject]@{ Action = "Coverage";    Order = 40; Script = "build-test-codecoverage.ps1"; Description = "Run tests and generate a coverage report." }
    [pscustomobject]@{ Action = "Integration"; Order = 50; Script = "build-integration.ps1";       Description = "Run integration tests for this repository." }
    [pscustomobject]@{ Action = "Benchmark";   Order = 60; Script = "build-benchmark.ps1";         Description = "Run benchmark workloads for this repository." }
    [pscustomobject]@{ Action = "Pack";        Order = 70; Script = "build-pack.ps1";              Description = "Pack this repository's publishable artifacts." }
)

$systemActionMetadata = @(
    [pscustomobject]@{ Action = "Build";   Order = 1; Script = "pack-local-feed.ps1";    Description = "Build all publishable projects and refresh the local NuGet feed." }
    [pscustomobject]@{ Action = "Clean";   Order = 2; Script = "clean-artifacts.ps1";    Description = "Remove workspace generated artifacts." }
    [pscustomobject]@{ Action = "Rebuild"; Order = 3; Script = "rebuild-local-feed.ps1"; Description = "Clean generated artifacts, then rebuild the local NuGet feed." }
)

# ---------------------------------------------------------------------------
# System script discovery — scr/*.ps1 at workspace root
# ---------------------------------------------------------------------------
function Get-SystemScriptActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RootPath
    )

    $scrPath = Join-Path $RootPath "scr"
    if (-not (Test-Path $scrPath)) { return }

        foreach ($metadata in $systemActionMetadata) {
                $scriptPath = Join-Path $scrPath $metadata.Script
                if (-not (Test-Path $scriptPath)) { continue }

                [pscustomobject]@{
                        Repo        = "── SYSTEM ──"
                        Action      = $metadata.Action
                        Description = $metadata.Description
                        Order       = $metadata.Order
                        Script      = "scr\$($metadata.Script)"
                        RepoPath    = $RootPath
                        ScriptPath  = $scriptPath
                }
        }

        $reservedScripts = @($systemActionMetadata.Script)
        $order = 100

    @(Get-ChildItem -Path $scrPath -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $reservedScripts } |
      Sort-Object Name) |
    ForEach-Object {
        # release-nuget-from-local.ps1 → "Release Nuget From Local"
        $baseName    = $_.BaseName -replace '-', ' '
        $displayName = (Get-Culture).TextInfo.ToTitleCase($baseName)

        [pscustomobject]@{
            Repo        = "── SYSTEM ──"
            Action      = $displayName
            Description = Get-SystemScriptDescription -ScriptName $_.Name -DisplayName $displayName
            Order       = $order
            Script      = "scr\$($_.Name)"
            RepoPath    = $RootPath
            ScriptPath  = $_.FullName
        }

        $order++
    }
}

function Get-SystemScriptDescription {
    param(
        [Parameter(Mandatory)] [string] $ScriptName,
        [Parameter(Mandatory)] [string] $DisplayName
    )

    switch ($ScriptName) {
        "clean-artifact-packages.ps1" { "Remove local package feed and package staging artifacts."; break }
        "clean-artifact-reports.ps1"  { "Remove generated reports while preserving build/package outputs."; break }
        "create-all-repos.ps1"        { "Create or initialize configured child repositories."; break }
        "docker-down.ps1"             { "Stop the workspace Docker development infrastructure."; break }
        "docker-reset.ps1"            { "Reset workspace Docker services and generated container state."; break }
        "docker-status.ps1"           { "Show Docker infrastructure readiness and service status."; break }
        "docker-up.ps1"               { "Start Docker infrastructure and run readiness checks."; break }
        "pack-all.ps1"                { "Pack all library repositories using the legacy pack-all workflow."; break }
        "release-nuget-from-github.ps1" { "Tag and push a NuGet release through GitHub automation."; break }
        "release-nuget-from-local.ps1"  { "Publish NuGet packages from the local artifact feed."; break }
        "build-book.ps1"              { "Generate the KoreForge Ecosystem Reference PDF book."; break }
        "zip-compact-workspace.ps1"   { "Create a compact workspace archive under artifacts/zips."; break }
        "zip-workspace.ps1"           { "Create a full workspace archive under artifacts/zips."; break }
        default                        { "Run workspace script: $DisplayName." }
    }
}

# ---------------------------------------------------------------------------
# Repository discovery — scans 2 levels deep
# ---------------------------------------------------------------------------
function Test-IsRepository {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [System.IO.DirectoryInfo] $Directory)

    (Test-Path (Join-Path $Directory.FullName ".git")) -or
    (@(Get-ChildItem -Path $Directory.FullName -Filter "*.sln"  -File -ErrorAction SilentlyContinue).Count -gt 0) -or
    (@(Get-ChildItem -Path $Directory.FullName -Filter "*.slnx" -File -ErrorAction SilentlyContinue).Count -gt 0) -or
    (@(Get-ChildItem -Path $Directory.FullName -Filter "*.csproj" -File -ErrorAction SilentlyContinue).Count -gt 0) -or
    (Test-Path (Join-Path $Directory.FullName "scr"))
}

function Get-KoreForgeRepositories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $level1 = @(Get-ChildItem -Path $RootPath -Directory -ErrorAction Stop)

    foreach ($dir in $level1) {
        if (Test-IsRepository $dir) {
            if ($seen.Add($dir.FullName)) {
                $dir
            }
        }
        else {
            $children = @(Get-ChildItem -Path $dir.FullName -Directory -ErrorAction SilentlyContinue)
            foreach ($child in $children) {
                if (Test-IsRepository $child) {
                    if ($seen.Add($child.FullName)) {
                        $child
                    }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Standard action discovery
# ---------------------------------------------------------------------------
function Get-AvailableScriptActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo[]] $Repositories,
        [Parameter(Mandatory)] [object[]]                  $Actions
    )

    # Offset repo actions so they always sort after system actions (order 1..N)
    $repoOrderBase = 1000

    foreach ($repo in $Repositories) {
        foreach ($action in $Actions) {
            $scriptPath = Join-Path $repo.FullName (Join-Path "scr" $action.Script)
            if (Test-Path $scriptPath) {
                [pscustomobject]@{
                    Repo        = $repo.Name
                    Action      = $action.Action
                    Description = $action.Description
                    Order       = $repoOrderBase + $action.Order
                    Script      = "scr\$($action.Script)"
                    RepoPath    = $repo.FullName
                    ScriptPath  = $scriptPath
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Stress script discovery
# ---------------------------------------------------------------------------
function Get-StressScriptActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.IO.DirectoryInfo[]] $Repositories
    )

    $order = 2000

    foreach ($repo in $Repositories) {
        $scrPath = Join-Path $repo.FullName "scr"
        if (-not (Test-Path $scrPath)) { continue }

        $stressScripts = @(Get-ChildItem -Path $scrPath -Filter "run-stress-*.ps1" -File -ErrorAction SilentlyContinue |
                           Sort-Object Name)

        foreach ($script in $stressScripts) {
            $baseName    = $script.BaseName -replace '^run-stress-', ''
            $words       = ($baseName -split '-') | ForEach-Object {
                               if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
                           }
            $displayName = "Stress: $($words -join ' ')"

            [pscustomobject]@{
                Repo        = $repo.Name
                Action      = $displayName
                Description = "Run stress workload '$($words -join ' ')'."
                Order       = $order
                Script      = "scr\$($script.Name)"
                RepoPath    = $repo.FullName
                ScriptPath  = $script.FullName
            }

            $order++
        }
    }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function New-LogPath {
    param(
        [Parameter(Mandatory)] [string] $LogRoot,
        [Parameter(Mandatory)] [string] $Repo,
        [Parameter(Mandatory)] [string] $Action
    )
    $safeName = "$Repo`__$Action.log" -replace '[^\w\.-]', '_'
    Join-Path $LogRoot $safeName
}

function Get-InterestingErrorLines {
    param([Parameter(Mandatory)] [string] $LogPath)

    if (-not (Test-Path $LogPath)) { return @() }

    @(Get-Content $LogPath -ErrorAction SilentlyContinue |
        Where-Object {
            $_ -match 'error\s+CS\d+'             -or
            $_ -match 'error\s+MSB\d+'            -or
            $_ -match 'error\s+NU\d+'             -or
            $_ -match ':\s*error\s+'              -or
            $_ -match 'Build FAILED'              -or
            $_ -match '\bFAILED\b'                -or
            $_ -match '\bException\b'             -or
            $_ -match 'A parameter cannot be found' -or
            $_ -match 'ParameterBindingException'
        } |
        Select-Object -First 80)
}

function Find-ReportFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RepoPath,
        [string] $LogPath
    )

    $files = [System.Collections.Generic.List[object]]::new()

    $repoName = Split-Path $RepoPath -Leaf
    $artifactRoot = $env:KOREFORGE_ARTIFACTS_ROOT

    $candidateRoots = @(
        $(if ($artifactRoot) { Join-Path $artifactRoot (Join-Path "repos" $repoName) }),
        $(if ($artifactRoot) { Join-Path $artifactRoot "test-results" }),
        $(if ($artifactRoot) { Join-Path $artifactRoot "coverage" }),
        $(if ($artifactRoot) { Join-Path $artifactRoot "reports" }),
        (Join-Path $RepoPath "out"),
        (Join-Path $RepoPath "out\TestResults"),
        (Join-Path $RepoPath "TestResults"),
        (Join-Path $RepoPath "coverage-report"),
        (Join-Path $RepoPath "artifacts"),
        (Join-Path $RepoPath ".artifacts"),
        (Join-Path $RepoPath "out\StressResults")
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $candidateRoots) {
        Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -in @(".trx", ".html", ".xml") -and (
                    $_.Name -eq "TestResults.html" -or
                    $_.Name -eq "index.html"       -or
                    $_.Name -eq "coverage.cobertura.xml" -or
                    $_.Name -like "stress-*.html"  -or
                    $_.Extension -eq ".trx"
                )
            } |
            ForEach-Object {
                $type = switch -Regex ($_.FullName) {
                    'coverage.*index\.html$'   { "CoverageHtml"; break }
                    'TestResults\.html$'       { "TestHtml";     break }
                    'coverage\.cobertura\.xml$'{ "CoverageXml";  break }
                    'stress-.*\.html$'         { "StressHtml";   break }
                    '\.trx$'                   { "Trx";          break }
                    default                    { "Report" }
                }
                $files.Add([pscustomobject]@{
                    Type          = $type
                    Name          = $_.Name
                    FullName      = $_.FullName
                    LastWriteTime = $_.LastWriteTime
                })
            }
    }

    if ($LogPath -and (Test-Path $LogPath)) {
        Get-Content $LogPath -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '(Test results|Coverage report|Stress report):\s*(.+)$' } |
            ForEach-Object {
                $label   = $Matches[1]
                $rawPath = $Matches[2].Trim().Trim('"').Trim("'")

                if (-not [System.IO.Path]::IsPathRooted($rawPath)) {
                    $rawPath = Join-Path $RepoPath $rawPath
                }

                if (Test-Path $rawPath) {
                    $resolved = (Resolve-Path $rawPath).Path
                    $type     = switch ($label) {
                        "Coverage report" { "CoverageHtml" }
                        "Stress report"   { "StressHtml"   }
                        default           { "TestHtml"     }
                    }
                    $files.Add([pscustomobject]@{
                        Type          = $type
                        Name          = Split-Path $resolved -Leaf
                        FullName      = $resolved
                        LastWriteTime = (Get-Item $resolved).LastWriteTime
                    })
                }
            }
    }

    $files | Sort-Object FullName -Unique | Sort-Object Type, FullName
}

function Get-ScriptParameterNames {
    param([Parameter(Mandatory)] [string] $ScriptPath)

    try {
        $tokens = $null; $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors -and $parseErrors.Count -gt 0) { return @() }
        if (-not $ast.ParamBlock)                       { return @() }
        return @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    }
    catch { return @() }
}

function New-PowerShellScriptArguments {
    param(
        [Parameter(Mandatory)] [string] $ScriptPath,
        [Parameter(Mandatory)] [string] $Configuration,
        [string] $Version
    )

    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath)
    $params    = @(Get-ScriptParameterNames -ScriptPath $ScriptPath)

    if ($params -contains "Configuration") { $arguments += @("-Configuration", $Configuration) }
    if ($Version -and $params -contains "Version") { $arguments += @("-Version", $Version) }

    return $arguments
}

function Invoke-ScriptAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Item,
        [Parameter(Mandatory)] [string] $Configuration,
        [string] $Version,
        [Parameter(Mandatory)] [string] $LogRoot
    )

    $logPath    = New-LogPath -LogRoot $LogRoot -Repo $Item.Repo -Action $Item.Action
    $stdErrPath = "$logPath.err"
    $started    = Get-Date
    $isStress   = $Item.Action -like "Stress:*"
    $isSystem   = $Item.Repo  -eq "── SYSTEM ──"

    Write-Host ""
    if ($isSystem) {
        Write-Host "▶ [SYSTEM] $($Item.Action)" -ForegroundColor Magenta
    }
    else {
        Write-Host "▶ $($Item.Repo) / $($Item.Action)" -ForegroundColor Cyan
    }

    if ($isStress) {
        Write-Host "  (stress tests may take several minutes)" -ForegroundColor DarkGray
    }

    $arguments = New-PowerShellScriptArguments `
        -ScriptPath    $Item.ScriptPath `
        -Configuration $Configuration `
        -Version       $Version

    $process = Start-Process `
        -FilePath "pwsh" `
        -ArgumentList $arguments `
        -WorkingDirectory $Item.RepoPath `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError  $stdErrPath `
        -WindowStyle Hidden

    if (Test-Path $stdErrPath) {
        $stderr = @(Get-Content $stdErrPath -ErrorAction SilentlyContinue)
        if ($stderr.Count -gt 0) {
            Add-Content -Path $logPath -Value ""
            Add-Content -Path $logPath -Value "----- STDERR -----"
            Add-Content -Path $logPath -Value $stderr
        }
        Remove-Item $stdErrPath -Force -ErrorAction SilentlyContinue
    }

    $duration = (Get-Date) - $started
    $success  = $process.ExitCode -eq 0

    if ($success) {
        Write-Host "✓ $($Item.Repo) / $($Item.Action) / $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    }
    else {
        Write-Host "✗ $($Item.Repo) / $($Item.Action) / ExitCode $($process.ExitCode)" -ForegroundColor Red

        $errors = Get-InterestingErrorLines -LogPath $logPath
        if ($errors.Count -gt 0) {
            Write-Host ""
            Write-Host "Likely errors:" -ForegroundColor Yellow
            $errors | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
        }
        else {
            Write-Host "No obvious error lines found. Open the full log." -ForegroundColor Yellow
        }
        Write-Host "Full log: $logPath" -ForegroundColor Yellow
    }

    [pscustomobject]@{
        Repo     = $Item.Repo
        Action   = $Item.Action
        IsStress = $isStress
        IsSystem = $isSystem
        Success  = $success
        ExitCode = $process.ExitCode
        Duration = $duration.ToString("hh\:mm\:ss")
        LogPath  = $logPath
        RepoPath = $Item.RepoPath
    }
}

function Read-ConfigurationChoice {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Debug", "Release")]
        [string] $DefaultConfiguration
    )

    $choice = Read-Host "Build configuration [Debug/Release] (default: $DefaultConfiguration)"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $DefaultConfiguration }
    if ($choice -in @("Debug", "Release"))     { return $choice }
    throw "Invalid configuration '$choice'. Use Debug or Release."
}

function Read-VersionChoice {
    $version = Read-Host "NuGet release version, e.g. 1.0.1-alpha  (leave blank to skip)"
    return $version.Trim()
}

function Open-SelectedFiles {
    param(
        [Parameter(Mandatory)] [object[]] $Files,
        [Parameter(Mandatory)] [string]   $Title
    )

    $selected = $Files |
        Select-Object Name, FullName, LastWriteTime |
        Out-ConsoleGridView -OutputMode Multiple -Title $Title

    if (-not $selected -or $selected.Count -eq 0) { return }
    foreach ($f in $selected) { Invoke-Item $f.FullName }
}

function Show-ReportOutputs {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Results)

    $reportableResults = @($Results | Where-Object {
        $_.Action -in @("Test", "Coverage", "Integration") -or $_.Action -like "Stress:*"
    })

    if ($reportableResults.Count -eq 0) { return @() }

    $reportFiles = @(
        foreach ($result in $reportableResults) {
            Find-ReportFiles -RepoPath $result.RepoPath -LogPath $result.LogPath |
                Select-Object `
                    @{Name="Repo";   Expression={ $result.Repo }},
                    @{Name="Action"; Expression={ $result.Action }},
                    Type, Name, FullName, LastWriteTime
        }
    ) | Sort-Object Repo, Action, Type, FullName -Unique

    if ($reportFiles.Count -eq 0) {
        Write-Host ""
        Write-Host "No test/stress/coverage output files were found." -ForegroundColor Yellow
        return @()
    }

    Write-Host ""
    Write-Host "Reports found:" -ForegroundColor Cyan
    $reportFiles |
        Format-Table `
            @{Name="Repo";     Expression={ $_.Repo };     Width=28 },
            @{Name="Action";   Expression={ $_.Action };   Width=36 },
            @{Name="Type";     Expression={ $_.Type };     Width=12 },
            @{Name="FullName"; Expression={ $_.FullName };           } `
            -Wrap

    return $reportFiles
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$rootPath = (Resolve-Path $Root).Path
$artifactRoot = Join-Path $rootPath "artifacts"
$env:KOREFORGE_WORKSPACE_ROOT = $rootPath
$env:KOREFORGE_ARTIFACTS_ROOT = $artifactRoot
$env:NO_COLOR = '1'   # suppress ANSI sequences in child process stdout/stderr (log files)
$selectedConfiguration = Read-ConfigurationChoice -DefaultConfiguration $Configuration

Write-Host "Root         : $rootPath"              -ForegroundColor Cyan
Write-Host "Artifacts    : $artifactRoot"          -ForegroundColor Cyan
Write-Host "Configuration: $selectedConfiguration" -ForegroundColor Cyan

# System scripts (workspace root scr/)
$systemActions = @(Get-SystemScriptActions -RootPath $rootPath)

# Repo scripts
$repositories = @(Get-KoreForgeRepositories -RootPath $rootPath | Sort-Object Name)

if ($repositories.Count -eq 0 -and $systemActions.Count -eq 0) {
    throw "No repositories or system scripts found under '$rootPath'."
}

Write-Host "Repositories : $($repositories.Count) found" -ForegroundColor Cyan
Write-Host "System scripts: $($systemActions.Count) found" -ForegroundColor Cyan

$standardScriptActions = @(Get-AvailableScriptActions -Repositories $repositories -Actions $standardActions)
$stressScriptActions   = @(Get-StressScriptActions    -Repositories $repositories)

# Merge: system first (order 1..N), then repo actions (order 1000+), then stress (2000+)
$availableActions = @($systemActions) + @($standardScriptActions) + @($stressScriptActions)

if ($availableActions.Count -eq 0) {
    throw "No scripts found."
}

$selected = $availableActions |
    Select-Object Repo, Action, Description, Order, Script, RepoPath, ScriptPath |
    Out-ConsoleGridView -OutputMode Multiple -Title "KoreForge Script Runner v5 — select scripts to run (SPACE to multi-select)"

if (-not $selected -or $selected.Count -eq 0) {
    Write-Host "No scripts selected." -ForegroundColor Yellow
    return
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logRoot   = Join-Path $artifactRoot "script-runner\logs\$timestamp"
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null

$orderedSelection = @($selected | Sort-Object Order, Repo)
$selectedVersion  = $null

# Ask for version if any system release script or any ReleaseNuGet repo script was selected
$needsVersion = @($orderedSelection | Where-Object {
    $_.Repo -eq "── SYSTEM ──" -and ($_.Action -like "*Release*" -or $_.Action -like "*Nuget*") -or
    $_.Action -like "ReleaseNuGet*"
}).Count -gt 0

if ($needsVersion) {
    $selectedVersion = Read-VersionChoice
    if (-not [string]::IsNullOrWhiteSpace($selectedVersion)) {
        Write-Host "NuGet release version: $selectedVersion" -ForegroundColor Cyan
    }
}

$results = foreach ($item in $orderedSelection) {
    Invoke-ScriptAction `
        -Item          $item `
        -Configuration $selectedConfiguration `
        -Version       $selectedVersion `
        -LogRoot       $logRoot
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "───────" -ForegroundColor Cyan

$results |
    Format-Table `
        @{Name="Repo";     Expression={ $_.Repo };                                    Width=28 },
        @{Name="Action";   Expression={ $_.Action };                                  Width=36 },
        @{Name="Result";   Expression={ if ($_.Success) { "✓" } else { "✗" } };      Width=8  },
        @{Name="ExitCode"; Expression={ $_.ExitCode };                                Width=10 },
        @{Name="Duration"; Expression={ $_.Duration };                                Width=14 },
        @{Name="LogPath";  Expression={ $_.LogPath };                                          } `
        -Wrap

$summaryCsv = Join-Path $logRoot "summary.csv"
$results | Export-Csv $summaryCsv -NoTypeInformation
Write-Host "Summary CSV: $summaryCsv" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Failed log offer
# ---------------------------------------------------------------------------
$failed = @($results | Where-Object { -not $_.Success })

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed logs:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "$($_.Repo) / $($_.Action): $($_.LogPath)" -ForegroundColor Yellow }

    $openLogs = Read-Host "Open failed logs? Y/N"
    if ($openLogs -match '^[Yy]') {
        $failed | ForEach-Object { Invoke-Item $_.LogPath }
    }
}

# ---------------------------------------------------------------------------
# Report / stress output offer
# ---------------------------------------------------------------------------
$reportFiles = @(Show-ReportOutputs -Results $results)

if ($reportFiles.Count -gt 0) {
    $openReports = Read-Host "Open selected output files? Y/N"
    if ($openReports -match '^[Yy]') {
        Open-SelectedFiles -Files $reportFiles -Title "Select reports to open"
    }
}

Write-Host ""
Write-Host "Logs saved to: $logRoot" -ForegroundColor Cyan
