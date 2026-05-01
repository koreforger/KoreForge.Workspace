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

## builder-v5

`builder-v5.ps1` is the front door. It discovers workspace-level scripts and per-repo scripts, runs selected actions, captures logs, and offers to open test/coverage/stress reports.

The intended refinement is for `builder-v5.ps1` to use `builder-v5.config.json` as a curated manifest while keeping discovery as fallback.

## Package Development

No project references are allowed. For local development:

1. Build and test the producer package.
2. Pack it as `1.0.1-alpha` or the next test version.
3. Put the `.nupkg` in `.artifacts/packages`.
4. Restore/build the consumer against the local feed.

## Version For Publishing Tests

Use `1.0.1-alpha`. If a second test publish is required, increment the patch number: `1.0.2-alpha`, then `1.0.3-alpha`.
