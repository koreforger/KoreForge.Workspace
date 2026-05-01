---
name: koreforge-builder-scripts
description: "Use when adding, fixing, or documenting repo scripts for builder.ps1 discovery: build-clean, build-rebuild, build-test, coverage, integration, benchmark, pack, stress scripts, and workspace scr scripts."
---

# KoreForge Builder Scripts

Use this skill when adding a repo to the workspace runner or repairing script discovery.

## Concepts

- `builder.ps1` is the interactive runner.
- `build.ps1` is the simple root front door.
- `builder.config.json` is the workspace manifest.
- Workspace scripts live in root `scr/`.
- Repo scripts live in each repo's `scr/` folder.
- Child helpers use `scr/koreforge-build.psm1`.

## Standard Repo Scripts

Add scripts only when the action applies:

| Script | Purpose |
| --- | --- |
| `build-clean.ps1` | Clean repo build output and repo artifact folders. |
| `build-rebuild.ps1` | Restore and rebuild. |
| `build-test.ps1` | Build and run unit tests. |
| `build-test-codecoverage.ps1` | Build, test, and generate coverage report. |
| `build-integration.ps1` | Run integration tests. |
| `build-benchmark.ps1` | Run BenchmarkDotNet benchmarks. |
| `build-pack.ps1` | Pack publishable artifacts. |

Stress scripts use `run-stress-*.ps1` and should print `Stress report: <path>` when they produce an HTML report.

## Add A Repo To Builder

1. Ensure the repo is listed in `builder.config.json`.
2. Add or update `scr/koreforge-build.psm1` from an existing current repo.
3. Add applicable standard scripts that import the helper module.
4. Keep repo-specific values minimal: solution name, repo name, package tag prefix, and benchmark path.
5. Confirm scripts can run from outside the repo.

## Script Rules

- Scripts must use paths relative to their own repo or workspace root.
- Scripts must restore the caller's location with `Push-Location`/`Pop-Location` when they change location.
- Scripts must route output under root `artifacts/`.
- Scripts must not write persistent output to child repo roots.
- Scripts must not introduce project references or vendored source shortcuts.

## Validation

```powershell
pwsh -File build.ps1 -CleanReports
pwsh -File <repo>/scr/build-test.ps1
pwsh -File <repo>/scr/build-pack.ps1 -Version 1.0.1-alpha
```

Parse all scripts after broad edits:

```powershell
Get-ChildItem -Recurse -Include *.ps1,*.psm1 -File |
  Where-Object FullName -NotMatch '\\(\.git|artifacts|bin|obj|node_modules)\\' |
  ForEach-Object {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    $errors
  }
```
