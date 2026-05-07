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
- `KoreForge.*` is legacy and should be retired when touched.
- Event-owned code uses `Event.*` and must not be renamed to `KoreForge.*`.
- Branches are `main` for stable and `development` for active work.

## File Content Rules

- Every source file must contain exactly one top-level type: one class, one record, one enum, one interface, or one struct. No file may contain multiple top-level type declarations.
- The file name must exactly match the single type it contains (e.g. `OrderService.cs` contains only `class OrderService`).

## File Naming Consistency Rules

- Before creating any file, look at files of the same kind already in the repo and adopt the exact same naming pattern. Do not invent a new pattern if one already exists.
- The word order in a filename establishes the pattern for that category. Once established, all files in that category follow the same word order. Examples: if publish workflows are named `publish-nuget.yml`, a new npm publish workflow must be `publish-npm.yml` — not `npm-publish.yml`. If scripts are named `build-test.ps1`, a new coverage script is `build-coverage.ps1` — not `coverage-build.ps1`.
- After creating or renaming any file, explicitly verify that its name and location match the established pattern for that file type in this workspace.

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

## KoreForge Package Skills

The following SKILL.md files encode correct usage patterns for each KoreForge library. Load the relevant skill before implementing any feature that touches these libraries.

| Skill name | Trigger |
|------------|---------|
| `koreforge-logging` | Adding or fixing structured logging; never use `ILogger<T>` directly |
| `koreforge-metrics` | Adding `IOperationMonitor` instrumentation, snapshot endpoint |
| `koreforge-applifecycle` | Startup flows, shutdown flows, scheduled flows, lifecycle events |
| `koreforge-settings` | SQL-backed live-reload config, `ISettingsService`, `IHistoryService` |
| `koreforge-kafka` | Kafka producer, consumer, or admin client integration |
| `koreforge-odata` | OData endpoints, `[ODataAuthorize]`, `[ODataIgnore]`, row-level filters |
| `koreforge-data` | EF Core scaffold, `Generated/` rules, partial class extensions, lookup tables |
| `koreforge-web` | **Router** for KoreForge.Web work — pick the right sub-skill below |
| `koreforge-web-restapi-layers` | Multi-layer RestApi scaffold (External/Domain/Internal/Client), Refit rules, API001–API007 analyzers, audit |
| `koreforge-web-authorization` | **Router** for KoreForge.Web.Authorization — choose attribute vs dynamic flavor |
| `koreforge-web-authorization-attribute` | Static `[RolesAuthorize]` + `IContextAuthorizationCondition` on MVC controllers |
| `koreforge-web-authorization-dynamic` | Runtime-mutable `MethodPermissionRule` + `PermissionsAuthorizationMiddleware`, custom stores |
| `koreforge-web-healthchecks` | `MapKfHealthEndpoints`, `HealthTags` (Ready/Live/Sql/Kafka), K8s probes |
| `koreforge-processing` | `PipelineBuilder`, `BatchPipelineExecutor`, `IPipelineStep` |
| `koreforge-json` | `RootPropertyClassifier`, `JsonMaterializer.Expand` |
| `koreforge-time` | `ISystemClock`, `VirtualSystemClock` — never use `DateTime.UtcNow` directly |
| `koreforge-monitoring` | Heartbeat registry, monitoring shell protocol |

Whenever development reveals new information about how a KoreForge library works — a constraint, a correct usage pattern, a mistake to avoid, or a feature not yet documented — update the associated SKILL.md immediately to reflect that knowledge. If the new knowledge spans multiple skills or covers a library not yet listed, create a new skill under `.github/skills/<skill-name>/SKILL.md` and add it to this table.
