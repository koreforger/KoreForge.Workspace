---
name: koreforge-template-authoring
description: "Use when creating, updating, testing, or packaging KoreForge dotnet templates, template samples, .template.config files, or template package behavior. Keywords: KoreForge.Templates, dotnet new, template package, sample exclusion."
---

# KoreForge Template Authoring

Use this skill for `KoreForge.Templates` and any `dotnet new` template work.

## Ground Rules

- Templates generate starter projects; they are not dependency shortcuts.
- Template sample projects are excluded from normal local feed packing.
- Template packages may be packed explicitly when releasing templates.
- Generated sample output belongs under `artifacts/` during tests.
- Do not vendor package source into templates.

## Inspect First

1. `packages/KoreForge.Templates/README.md`.
2. Template folders under `packages/KoreForge.Templates/templates/`.
3. `.template.config/template.json` in the template being changed.
4. Root `scr/pack-local-feed.ps1` and `scr/pack-all.ps1` template exclusions.
5. `docs/ecosystem/Introduction/53-Templates.md`.

## Add Or Update A Template

1. Create or update the template folder under `packages/KoreForge.Templates/templates/`.
2. Add `.template.config/template.json` with clear identity, short name, symbols, and source renames.
3. Use `PackageReference` entries for KoreForge dependencies.
4. Pin package versions through the intended template mechanism.
5. Add template-local `README.md` if the generated project needs user-facing instructions.
6. Ensure generated projects do not contain vendored KoreForge source.

## Test A Template

Use an output path under `artifacts/`:

```powershell
dotnet new install packages/KoreForge.Templates
dotnet new <short-name> -n TemplateSmoke -o artifacts/template-smoke/TemplateSmoke
```

Then build/test the generated project using its scripts when present.

## Pack Templates

```powershell
pwsh -File packages/KoreForge.Templates/scr/build-pack.ps1 -Version 1.0.1-alpha
```

For coordinated releases, use the workspace pack/release scripts and confirm template samples are excluded from normal runtime package packing.

## Validation

- Generated project restores from NuGet packages, not project references.
- Generated files use correct `KoreForge.*` or `Event.*` names.
- Template package output is under root `artifacts/`.
- No sample/test output is tracked.
