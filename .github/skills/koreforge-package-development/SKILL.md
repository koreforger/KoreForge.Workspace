---
name: koreforge-package-development
description: "Use when changing a KoreForge package, validating package-only local development, packing to artifacts/packages, updating consumers, or avoiding ProjectReference/vendor shortcuts. Keywords: PackageReference, local feed, NuGet, artifacts/packages, no ProjectReference, no vendored projects."
---

# KoreForge Package Development

Use this skill when changing a KoreForge package or a consumer of a KoreForge package.

## Ground Rules

- Use NuGet packages only for cross-project dependencies.
- Use `PackageReference`; never add `ProjectReference`.
- Never vendor a project or copy source from one repo into another.
- Use `artifacts/packages` as the local feed before nuget.org.
- Keep all generated output under root `artifacts/`.

## Inspect First

1. Read the producer repo `README.md` and `doc/` docs if present.
2. Check the producer package ID in its `.csproj`.
3. Check the consumer's `PackageReference` and `VersionOverride` values.
4. Check root `NuGet.config` to confirm the local feed points at `artifacts/packages`.
5. Check `docs/ecosystem/build-and-release.md` for current version and artifact rules.

## Workflow

1. Make the package change in the producer repo.
2. Run the producer tests:

```powershell
pwsh -File packages/<Repo>/scr/build-test.ps1
```

3. Pack the producer with the local test version:

```powershell
pwsh -File packages/<Repo>/scr/build-pack.ps1 -Version 1.0.1-alpha
```

4. Copy or pack into the local feed using the workspace pack script when multiple packages are involved:

```powershell
pwsh -File scr/pack-local-feed.ps1 -Version 1.0.1-alpha
```

5. Restore and test the consumer against the local feed.
6. If repeated local publish tests are needed, increment the patch number: `1.0.2-alpha`, `1.0.3-alpha`.

## Validation

- `rg "<ProjectReference" -g "*.csproj"` returns no hits.
- Local packages are in `artifacts/packages`.
- Tests pass through repo scripts.
- No generated files are tracked.
- Consumer builds from package restore, not source references.

## Never Do This

- Do not add a temporary `ProjectReference`.
- Do not copy source files between repos.
- Do not add git submodules to simulate vendoring.
- Do not point a consumer directly at another repo's `bin` output.
