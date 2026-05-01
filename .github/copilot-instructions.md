# KoreForge Workspace Instructions

These instructions apply to all work in this workspace. Follow them before local conventions unless the user explicitly overrides them.

## Dependency Rules

- Use NuGet packages only for cross-project dependencies.
- Use `PackageReference` for dependencies on KoreForge, Event, Microsoft, and third-party libraries.
- Never add a `ProjectReference` to any `.csproj` file.
- Never vendor projects, source trees, generated SDKs, or third-party code into this workspace.
- Never copy a package's source into an app or another package to avoid publishing/restoring a NuGet package.
- Local development uses the workspace NuGet feed at `artifacts/packages` before nuget.org.
- If a consumer needs a changed package, build and pack the producer package, put the `.nupkg` in `artifacts/packages`, then restore the consumer.

## Artifact Rules

- All generated output belongs under the workspace root `artifacts/` directory.
- Do not create persistent `bin`, `obj`, `out`, `TestResults`, coverage, reports, benchmark, package, or zip output in child repo roots.
- Use repo scripts and workspace scripts because they route output through `artifacts/`.
- Do not check in generated artifacts.

## Naming Rules

- KoreForge-owned repos, packages, assemblies, projects, and namespaces should use `KoreForge.*`.
- `KF.*` is legacy and should be retired when touched.
- Event-owned code uses `Event.*` and must not be renamed to `KoreForge.*`.
- Branches are `main` for stable and `development` for active work.

## Build And Script Rules

- Use `builder.ps1` for interactive script discovery.
- Use `build.ps1` for the simple front door and cleanup switches.
- Child repos expose standard scripts under `scr/`.
- The workspace manifest is `builder.config.json`.
- Child `scr/koreforge-build.psm1` helpers detect the workspace root by finding `builder.config.json`.

## Documentation Rules

- Follow `docs/ecosystem/documentation-standard.md` for document types and canonical names.
- Use only these normal child-repo documentation types: specification, detailed design, user guide, developer guide, structure, and rare deeper explanations.
- Keep the workspace root docs broader when needed, but classify new docs clearly.
- Update `docs/ecosystem/documentation-inventory.md` when adding or reclassifying durable docs.

## Infrastructure Rules

- Prefer infrastructure readiness checks and bootstrap ordering over production-code retries for Docker readiness problems.
- SQL bootstrap scripts must fail fast when SQL commands fail.
- Do not commit runtime database files, Kafka data, logs, checkpoints, or generated container state.

## Git Rules

- Do not revert user changes unless explicitly asked.
- Do not run destructive git commands unless explicitly asked.
- Commit only when the user asks or when the current workflow clearly includes committing/pushing repository changes.
