# Build And Release Workflow

## Standard Repo Scripts

Every buildable repo should expose these scripts where applicable:

| Script | Purpose |
|---|---|
| `scr/build-clean.ps1` | Clean build outputs. |
| `scr/build-rebuild.ps1` | Restore and rebuild. |
| `scr/build-test.ps1` | Build and run tests. |
| `scr/build-test-codecoverage.ps1` | Build, test, and produce HTML coverage. |
| `scr/build-integration.ps1` | Run integration tests when present. |
| `scr/build-benchmark.ps1` | Run BenchmarkDotNet benchmarks when present. |
| `scr/build-pack.ps1` | Pack NuGet/npm artifacts when the repo is publishable. |
| `scr/release-nuget-from-local.ps1` | Publish a local NuGet package. |
| `scr/release-nuget-from-github.ps1` | Tag/push and let GitHub publish. |

## Builder

`builder.ps1` is the front door. It discovers workspace-level scripts and per-repo scripts, runs selected actions, captures logs, and offers to open test/coverage/stress reports.

`build.ps1` is the simple command-line front door. It launches `builder.ps1` by default and also exposes artifact cleanup switches.

## Artifact Policy

All generated output belongs under the workspace root `artifacts/` folder, which is ignored by git. No build, pack, test, coverage, report, benchmark, cleanup, or zip process should create persistent output in child repo roots.

Standard locations:

| Output | Location |
| --- | --- |
| Local NuGet feed | `artifacts/packages` |
| Package staging | `artifacts/packages/staging` |
| Script runner logs | `artifacts/script-runner/logs` |
| Per-repo test/coverage/pack output | `artifacts/repos/<repo>` |
| Workspace reports | `artifacts/reports` |
| Workspace zips | `artifacts/zips` |

Cleanup commands:

```powershell
.\build.ps1 -CleanArtifacts
.\build.ps1 -CleanPackages
.\build.ps1 -CleanReports
```

## Package Development

No project references are allowed. For local development:

1. Build and test the producer package.
2. Pack it as `1.0.1-alpha` or the next test version.
3. Put the `.nupkg` in `artifacts/packages`.
4. Restore/build the consumer against the local feed.

All packages in a coordinated local or public release use the same package version. Runtime packages should include PDBs so coverage and diagnostics can resolve package code.

Template sample projects are excluded from normal package-feed packing. Template packages can be packed explicitly when the template repo is being released.

## Branching

Repos standardize on `main` as the stable branch and `development` as the active work branch. Gitflow should be initialized consistently with those branch names.

## Version For Publishing Tests

Use `1.0.1-alpha`. If a second test publish is required, increment the patch number: `1.0.2-alpha`, then `1.0.3-alpha`.
