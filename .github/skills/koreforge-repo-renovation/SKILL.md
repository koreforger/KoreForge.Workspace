---
name: koreforge-repo-renovation
description: "Use when renovating, modernizing, renaming, or rebranding a KoreForge repo, especially retiring KoreForge.* names, fixing csproj/slnx paths, package metadata, namespaces, scripts, docs, tests, and NuGet packaging."
---

# KoreForge Repo Renovation

Use this skill for repo-wide cleanup, rename, modernization, or `KoreForge.*` retirement.

## Ground Rules

- Preserve user changes. Inspect status before editing.
- Keep edits scoped to the repo being renovated unless a shared contract requires broader changes.
- Use `KoreForge.*` for KoreForge repos, projects, assemblies, namespaces, and packages.
- Use NuGet `PackageReference` only; never add `ProjectReference`.
- Never vendor projects or source trees.
- Route generated output to root `artifacts/`.

## Inspect First

1. `git status --short` in the target repo.
2. Repo `.slnx`, `.csproj`, `Directory.Build.props`, and `Directory.Packages.props`.
3. `src/`, `tst/`, `scr/`, `doc/`, and `README.md`.
4. References from other repos with `rg "Old.Name|KF\."` from workspace root.
5. Existing package IDs in `PackageReference` entries.

## Rename Checklist

1. Rename folders and project files to the target `KoreForge.*` names.
2. Update `.slnx` paths.
3. Update `AssemblyName`, `RootNamespace`, package ID, and coverage include filters.
4. Update C# namespaces and usings.
5. Update package references in tests and consumers.
6. Update docs, scripts, and workflows.
7. Pack the producer into `artifacts/packages` before testing package-only consumers.
8. Remove stale old-name folders only after verifying they are duplicates or obsolete.

## Validation

```powershell
rg --no-ignore -n --glob '!**/.git/**' --glob '!artifacts/**' 'KF\.|OldName' <repo>
pwsh -File <repo>/scr/build-test.ps1
pwsh -File <repo>/scr/build-pack.ps1 -Version 1.0.1-alpha
```

Also verify:

- No `ProjectReference` exists.
- No repo-local generated artifacts are tracked.
- Package PDBs are included and copied for package-only coverage where needed.
- `git status --short` shows only intended changes before commit.

## Documentation

When renovating docs, use canonical names from `docs/ecosystem/documentation-standard.md` and update `docs/ecosystem/documentation-inventory.md`.
