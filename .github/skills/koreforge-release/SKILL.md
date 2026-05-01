---
name: koreforge-release
description: "Use when coordinating KoreForge package versions, packing all packages, publishing to NuGet.org, testing publish version 1.0.1-alpha, managing release scripts, or validating package artifacts and symbols."
---

# KoreForge Release

Use this skill for local package-feed releases, NuGet publishing, and coordinated version work.

## Ground Rules

- All packages in a coordinated release use the same package version.
- Use `1.0.1-alpha` for publish tests, then increment patch for repeated tests.
- Publish from packages under `artifacts/packages`.
- Runtime packages should include PDBs.
- Do not publish packages built from vendored source or project references.

## Inspect First

1. `docs/ecosystem/build-and-release.md`.
2. `scr/pack-local-feed.ps1`.
3. `scr/pack-all.ps1`.
4. `scr/release-nuget-from-local.ps1`.
5. `NuGet.config`.
6. Dirty status across all repos.

## Local Feed Pack

For development validation:

```powershell
pwsh -File scr/pack-local-feed.ps1 -Version 1.0.1-alpha -CleanFeed
```

For older/full pack orchestration:

```powershell
pwsh -File scr/pack-all.ps1 -Version 1.0.1-alpha
```

## Local NuGet Release

```powershell
pwsh -File scr/release-nuget-from-local.ps1 -Version <version>
```

The script reads the API key from `nuget-api.key.txt`. Do not print the key.

## Validation

- `.nupkg` files are under `artifacts/packages`.
- `.snupkg` files are produced when symbol packages are expected.
- Package contents include PDBs for runtime libraries.
- No generated package artifacts are tracked.
- `rg "<ProjectReference" -g "*.csproj"` returns no hits.
- Repos are clean before final release tagging or publishing.

## Failure Handling

- If restore fails because of dependency order, pack producer packages first and rerun.
- If coverage cannot instrument package code, check PDB inclusion and `CopyDebugSymbolFilesFromPackages`.
- If publish reports duplicate packages, treat duplicates as skipped when `--skip-duplicate` is in use.
