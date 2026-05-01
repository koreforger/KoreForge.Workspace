---
name: koreforge-new-project
description: "Use when adding a new KoreForge package, tool, npm package, or Event app to the workspace; configuring repo layout, NuGet package references, scripts, builder.config.json, docs, branches, and GitHub repo setup."
---

# KoreForge New Project

Use this skill when adding any new repo or project to the KoreForge workspace.

## Choose Ownership

| Ownership | Location | Naming |
| --- | --- | --- |
| KoreForge runtime package | `packages/` | `KoreForge.*` |
| Developer tool | `tools/` | `KoreForge.*` |
| npm/Vue package | `npm/` | `KoreForge.*` |
| Event app or Event library | `event/` | `Event.*` |

Do not put product code directly in the workspace root.

## Ground Rules

- Use NuGet `PackageReference` only.
- Never add `ProjectReference`.
- Never vendor another project or source tree.
- Route generated output under root `artifacts/`.
- Add standard scripts under repo `scr/`.
- Add the repo path to `builder.config.json`.
- Use `main` and `development` branches.

## Standard Runtime Package Layout

```text
packages/KoreForge.Area/
  Directory.Build.props
  Directory.Packages.props
  KoreForge.Area.slnx
  README.md
  LICENSE.md
  doc/
  scr/
  src/KoreForge.Area/KoreForge.Area.csproj
  tst/KoreForge.Area.Tests/KoreForge.Area.Tests.csproj
```

Adjust the `src/` and `tst/` project names when the repo intentionally contains multiple packages.

## Steps

1. Create the repo folder in the correct group.
2. Create solution, source project, tests, docs, and scripts following a current repo pattern.
3. Set package metadata in `.csproj` and `Directory.Build.props`.
4. Use package references for dependencies and central package management where appropriate.
5. Add standard repo scripts and `scr/koreforge-build.psm1`.
6. Add the repo path to `builder.config.json`.
7. Add docs using the standard taxonomy.
8. Add or create the GitHub repo under `koreforger` when ready.
9. Create/push `main` and `development`; work on `development`.

## Validation

```powershell
rg "<ProjectReference" -g "*.csproj"
pwsh -File <repo>/scr/build-test.ps1
pwsh -File <repo>/scr/build-pack.ps1 -Version 1.0.1-alpha
pwsh -File build.ps1 -CleanReports
```

Also check:

- `builder.ps1` can discover repo scripts.
- Package output lands under `artifacts/`.
- Docs are linked from the repo `README.md`.
- No generated files are tracked.
