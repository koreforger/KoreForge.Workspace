---
name: koreforge-builder-scripts
description: "Use when adding/fixing the per-repo scr/ scripts that builder.ps1 discovers (build-clean, build-rebuild, build-test, build-test-codecoverage, build-integration, build-benchmark, build-pack, run-stress-*), the koreforge-build.psm1 helper module, the workspace scr/ scripts, build.ps1, builder.ps1, builder.config.json, and the artifacts/ folder layout."
---

# KoreForge Builder & Repo Scripts Skill

## When to use

- Adding a script under a repo's [scr/](scr) folder so `builder.ps1` picks it up.
- Editing [build.ps1](build.ps1), [builder.ps1](builder.ps1), or [builder.config.json](builder.config.json).
- Fixing "the script wrote bin/obj into my repo" or "the script can't find the workspace root".
- Creating workspace-level orchestration scripts under root [scr/](scr).
- Onboarding a new repo so the runner discovers it.

If the question is about Docker, see [koreforge-docker-infra](../koreforge-docker-infra/SKILL.md). If it's about creating a brand-new repo, see [koreforge-new-project](../koreforge-new-project/SKILL.md).

## The three layers

```
build.ps1            ← root entry point, very thin; flags for clean only,
                       otherwise hands off to builder.ps1
builder.ps1          ← interactive ConsoleGuiTools menu of every action it
                       can find across repos + workspace scripts
builder.config.json  ← the manifest: paths to every repo, package version,
                       artifactsRoot, branch names
```

`builder.ps1` discovers actions by **filename convention**, not by configuration. If a script exists with the right name in a repo's `scr/` folder, it appears in the menu. If it does not exist, the action is hidden for that repo.

## Standard repo scripts (filename → action)

`builder.ps1` matches these names per repo:

| Filename | Menu action | Purpose |
|---|---|---|
| `scr/build-clean.ps1` | Clean | `dotnet clean` + remove repo's `artifacts/repos/<repo>` slice. |
| `scr/build-rebuild.ps1` | Rebuild | `dotnet build --force`. |
| `scr/build-test.ps1` | Test | Build + run unit tests (`FullyQualifiedName!~Integration`). |
| `scr/build-test-codecoverage.ps1` | Coverage | Test with `XPlat Code Coverage` + ReportGenerator HTML. |
| `scr/build-integration.ps1` | Integration | Tests whose name contains `Integration`. |
| `scr/build-benchmark.ps1` | Benchmark | Runs BenchmarkDotNet projects. |
| `scr/build-pack.ps1` | Pack | `dotnet pack -c Release` → `artifacts/repos/<repo>/packages`. |
| `scr/run-stress-*.ps1` | Stress: `<Name>` | Auto-discovered. Must print `Stress report: <path>`. |

Plus repo-specific NuGet release helpers:

| Filename | Purpose |
|---|---|
| `scr/release-nuget-from-github.ps1` | Tag and push (CI in the repo publishes). |
| `scr/release-nuget-from-local.ps1` | Build, pack, push to NuGet.org from local. |
| `scr/git-create-repo.ps1` | One-shot `git init` + `gh repo create`. |
| `scr/github-set-nuget-secret.ps1` | Pipe `NUGET_API_KEY` to `gh secret set`. |

Add a script **only when the action is meaningful** for the repo. Don't ship empty `build-benchmark.ps1` files — the menu silently skips missing scripts.

## The `koreforge-build.psm1` helper

Every repo's `scr/koreforge-build.psm1` is the same file (kept in sync across repos). All standard scripts are 4 lines:

```powershell
[CmdletBinding()]
param([ValidateSet('Debug','Release')][string]$Configuration = 'Debug')

Import-Module (Join-Path $PSScriptRoot 'koreforge-build.psm1') -Force -DisableNameChecking
Invoke-KoreForgeTest -Configuration $Configuration
```

Do not write business logic in the per-repo wrappers. Add features to the shared module and propagate the new module file to every repo.

Key functions in the module:

| Function | What it does |
|---|---|
| `Get-KoreForgeRepoRoot` | One level above `$PSScriptRoot`. |
| `Get-KoreForgeWorkspaceRoot` | Walks up looking for `builder.config.json`. Honors `$env:KOREFORGE_WORKSPACE_ROOT`. |
| `Get-KoreForgeArtifactRoot` | `<workspace>/artifacts` unless `$env:KOREFORGE_ARTIFACTS_ROOT` is set. |
| `Get-KoreForgeRepoArtifactPath -ChildPath x` | `<artifacts>/repos/<repo>/x` — *the* place to write per-repo output. |
| `Get-KoreForgeBuildTarget` | Picks the first `*.slnx`, then `*.csproj`. |
| `Invoke-KoreForgeDotNet` | Wraps `dotnet`, sets `$env:NUGET_PACKAGES = artifacts/nuget-cache`, and adds `--artifacts-path <repo-build-dir>` to `build/test/pack/clean`. **This is why `bin/obj` end up in `artifacts/`, not in the repo.** |
| `Get-KoreForgeTestProjects -Integration:$false/$true` | Reflection-free filter on `Microsoft.NET.Test.Sdk` + name contains `Integration`. |
| `Get-KoreForgePackableProjects` | Excludes `IsPackable=false`, test SDKs, and any path under `templates/`, `samples/`, `benchmarks/`. |
| `Invoke-KoreForge{Clean,Rebuild,Test,Coverage,Integration,Benchmark,Pack}` | The real bodies. |
| `Invoke-KoreForgeReleaseNuGetFromGitHub` / `…FromLocal` | Tag-push and pack-push flows. |

If you are tempted to do `dotnet build` directly in a script, use `Invoke-KoreForgeDotNet` instead — otherwise output lands in the repo's local `bin`/`obj` and breaks the artifact policy.

## Workspace scripts (root [scr/](scr))

`builder.ps1` shows these under `── SYSTEM ──`. Three are pinned (`Build`, `Clean`, `Rebuild`); everything else in `scr/*.ps1` appears alphabetically.

| Script | Purpose |
|---|---|
| [scr/clean-artifacts.ps1](scr/clean-artifacts.ps1) | Wipes `artifacts/` (preserving `script-runner` + `nuget-cache`) **and** scrubs stray `bin/obj/out/TestResults/...` from every repo under `eco-system`, `tools`, `event`, `eco-web`. |
| [scr/clean-artifact-packages.ps1](scr/clean-artifact-packages.ps1) | Removes the local NuGet feed only. |
| [scr/clean-artifact-reports.ps1](scr/clean-artifact-reports.ps1) | Removes generated reports only. |
| [scr/pack-local-feed.ps1](scr/pack-local-feed.ps1) | Topologically packs every group in `builder.config.json` to `artifacts/packages` (the local feed). |
| [scr/rebuild-local-feed.ps1](scr/rebuild-local-feed.ps1) | `clean-artifacts` + `pack-local-feed`. |
| [scr/pack-all.ps1](scr/pack-all.ps1) | Legacy pack-all flow used by release scripts. |
| [scr/release-nuget-from-github.ps1](scr/release-nuget-from-github.ps1) | Bumps deps, commits props, tags each repo in dep order — GitHub Actions publishes. |
| [scr/release-nuget-from-local.ps1](scr/release-nuget-from-local.ps1) | Builds and pushes from local. |
| [scr/docker-up.ps1](scr/docker-up.ps1), `docker-down`, `docker-reset`, `docker-status` | See [koreforge-docker-infra](../koreforge-docker-infra/SKILL.md). |
| `feature-branch.ps1`, `zip-workspace.ps1`, `build-book.ps1`, `decode-compact-zip.ps1`, `encode-compact-zip.ps1` | Ad-hoc utilities. |

## `builder.config.json` — manifest

```jsonc
{
  "version": 1,
  "packageVersion": "1.0.1-alpha",
  "artifactsRoot": "artifacts",
  "localPackageFeed": "artifacts/packages",
  "defaultBranch": "main",
  "developmentBranch": "development",
  "groups": [
    { "name": "KoreForge packages", "paths": [ "eco-system/KoreForge.Time", … ] },
    { "name": "KoreForge tools",    "paths": [ "tools/KoreForge.Jex.Cli", … ] },
    { "name": "KoreForge npm",      "paths": [ "eco-web/KoreForge.Scripts.Vue", … ] },
    { "name": "Event test apps",    "paths": [ "event/Event.Streaming", … ] },
    { "name": "Event apis",         "paths": [ "event/Event.FraudIntegration.Data", … ] }
  ]
}
```

When you add a new repo:

1. Append its workspace-relative path to the appropriate `groups[*].paths` array.
2. Place it in dependency order — `pack-local-feed.ps1` topologically sorts within a group, but the group order is the outer order.
3. The first repo with no internal deps is `KoreForge.Time`; keep it first.

`builder.ps1` ignores this list for *menu* discovery (it scans 1–2 directory levels for `.git`/`.slnx`/`.csproj`/`scr/`), but `pack-local-feed`, `pack-all`, and the release scripts depend on it strictly. Missing entries here = silently skipped during a release.

## `build.ps1` — root front door

Trivial; only meaningful flags:

```powershell
.\build.ps1                  # interactive (calls builder.ps1)
.\build.ps1 -CleanArtifacts  # wipe artifacts/ + repo bin/obj
.\build.ps1 -CleanPackages   # wipe local NuGet feed only
.\build.ps1 -CleanReports    # wipe generated reports only
.\build.ps1 -Configuration Release   # passed through to builder.ps1
```

Add new top-level switches **only** when there is a real workflow benefit — keep `build.ps1` thin and route everything else through `builder.ps1`.

## `builder.ps1` — interactive runner

When extending it:

- Add a new pinned system action: append to `$systemActionMetadata` (Action, Order, Script, Description) — that's all.
- Add a new standard repo action: append to `$standardActions` with the agreed `Order` and the filename to look for. Every repo that ships that filename will gain the menu entry.
- Add metadata for a new `scr/*.ps1` system script: extend the `switch` in `Get-SystemScriptDescription`. The script itself is auto-discovered.
- Stress scripts are auto-discovered via `run-stress-*.ps1`. They must emit `Stress report: <path>` to be openable from the post-run prompt.

## `artifacts/` folder layout

Everything generated lives here, ignored by git:

```
artifacts/
  packages/                       ← local NuGet feed (KoreForgeLocal source)
    staging/                      ← intermediate pack output before promotion
  nuget-cache/                    ← $env:NUGET_PACKAGES — package restore cache
  script-runner/logs/             ← per-action logs from builder.ps1
  repos/<repo-name>/
    build/                        ← --artifacts-path target → bin/, obj/, publish/
    test-results/                 ← *.html test logger output
    coverage/                     ← cobertura + ReportGenerator HTML
    packages/                     ← per-repo nupkg/snupkg
    tools/                        ← repo-local dotnet tools
  reports/                        ← workspace-wide report aggregations
  zips/                           ← workspace archives
  generator-baseline/             ← swagger generator baseline (do not delete)
  pack-all-output.txt             ← latest pack run log (root-level files allowed)
```

Hard rules:

- A repo may **never** create persistent output in its own root (`bin/`, `obj/`, `out/`, `TestResults/`, `coverage/`, `BenchmarkDotNet.Artifacts/`, an `artifacts/` folder inside the repo). [scr/clean-artifacts.ps1](scr/clean-artifacts.ps1) treats these as bugs and removes them.
- Per-repo output goes under `artifacts/repos/<repo>/...` via `Get-KoreForgeRepoArtifactPath`.
- The local NuGet feed (`artifacts/packages`) is the ground-truth feed when [NuGet.config](NuGet.config) maps `KoreForge.*`/`Event.*` → `KoreForgeLocal`.

## NuGet feed wiring (workspace [NuGet.config](NuGet.config))

```xml
<packageSources>
  <clear />
  <add key="KoreForgeLocal" value="artifacts/packages" />
  <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
</packageSources>
<packageSourceMapping>
  <packageSource key="KoreForgeLocal">
    <package pattern="KoreForge.*" />
    <package pattern="Event.*" />
  </packageSource>
  <packageSource key="nuget.org"><package pattern="*" /></packageSource>
</packageSourceMapping>
```

Per-repo `NuGet.config` files only list `nuget.org` so they can be cloned and built outside the workspace; the workspace-level config takes precedence in dev because of `Get-KoreForgeWorkspaceRoot` walking up to it.

## Onboarding a repo to the runner — checklist

1. Repo lives under `eco-system/`, `tools/`, `event/`, or `eco-web/`.
2. Has a `*.slnx` (or root `*.csproj`) at its root.
3. `scr/koreforge-build.psm1` copied from the latest version of another repo.
4. Standard `scr/build-*.ps1` wrappers added for the actions the repo supports.
5. Repo path appended to the matching group in [builder.config.json](builder.config.json).
6. Repo's [NuGet.config](NuGet.config) (if present) does not redefine `KoreForgeLocal`.
7. Verified: `pwsh -File ./builder.ps1` lists the repo and its actions; `Test` and `Pack` succeed; nothing was written to the repo's own root.
