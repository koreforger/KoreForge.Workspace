# Documentation Inventory

This inventory classifies the current markdown files by standard document type. It is intentionally descriptive: legacy filenames are listed where they are today, and should be renamed to canonical names when the owning repo is next renovated.

## Workspace Root

| Document | Type | Notes |
| --- | --- | --- |
| `README.md` | Structure, developer guide | Workspace entry point, layout, rules, daily workflow. |
| `docs/README.md` | Structure | Documentation entry point. |
| `docs/ecosystem/documentation-standard.md` | Structure | Canonical documentation taxonomy. |
| `docs/ecosystem/documentation-inventory.md` | Structure | This inventory. |
| `docs/skills/README.md` | Developer guide | Human and LLM skill catalog. |
| `.github/skills/parse-swagger/SKILL.md` | Skill | Stage-1 of KoreForge.SwaggerControllers: Swagger 2.0 → metadata.json. References under `references/`. |
| `docs/ecosystem/layout.md` | Structure | Workspace grouping and dependency rule. |
| `docs/ecosystem/naming.md` | Structure | Naming and package identity rules. |
| `docs/ecosystem/build-and-release.md` | Developer guide | Build, pack, release, artifacts, branch rules. |
| `docs/development/docker.md` | Developer guide, structure | Local infrastructure workflow. |
| `docs/ecosystem/monitoring-shell-spec.md` | Specification | Monitoring shell DTO contracts and capability registry. |
| `docs/ecosystem/frontend-spec.md` | Specification | Workspace-wide front-end + supporting back-end architecture. |
| `docs/ecosystem/KoreForge-Documentation.md` | User guide | Combined ecosystem narrative/reference, currently generated. |
| `docs/ecosystem/KoreForge-Developer-Guide.md` | Developer guide | Ecosystem contributor guide. |
| `docs/ecosystem/Introduction/*.md` | User guide, structure | Publish-ordered introduction docs. |
| `docs/ecosystem/Api/*.md` | User guide | Checked-in API reference docs. |

## Package Repos

| Repo | Specification | Detailed design | User guide | Developer guide | Structure or notes |
| --- | --- | --- | --- | --- | --- |
| KoreForge.AppLifecycle | `doc/Specification.md` | `doc/SampleWalkthrough.md` | `doc/UsageGuide.md` | `doc/DevelopmentGuide.md`, `doc/BuildAndRelease.md` | `doc/versioning-guide.md` |
| KoreForge.Data | None yet | None yet | `doc/UsageGuide.md` | `doc/DevelopmentGuide.md` | None yet |
| KoreForge.Jex | `doc/Specification.md` | None yet | `doc/User-Guide.md`, `doc/UserGuide.md`, `doc/Installation-Guide.md` | `doc/Developer-Guide.md` | `doc/README.md` needs review; appears extension-oriented |
| KoreForge.Json | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Kafka | None yet | `doc/AdminClient.md` | `doc/UsageGuide.md` | None yet | `samples/docker/README.md` |
| KoreForge.Logging | `doc/Specification.md` | None yet | `doc/user-guide.md` | `doc/developer-guide.md`, `doc/scripts.md` | `doc/versioning-guide.md`, analyzer release manifests |
| KoreForge.Logging.Serilog | `doc/Specification.md` | None yet | `doc/user-guide.md` | `doc/developer-guide.md`, `doc/scripts.md` | `doc/versioning-guide.md` |
| KoreForge.Metrics | `doc/Specification.md` | `doc/architecture-overview.md` | `doc/configuration-reference.md`, `doc/operations-playbook.md` | `doc/developer-integration-guide.md`, `doc/build-commands.md`, `doc/testing-and-benchmarks.md` | `doc/versioning-guide.md` |
| KoreForge.Metrics.AspNet | `doc/Specification.md` | `doc/architecture-overview.md` | `doc/configuration-reference.md`, `doc/operations-playbook.md` | `doc/developer-integration-guide.md`, `doc/build-commands.md`, `doc/testing-and-benchmarks.md` | `doc/versioning-guide.md` |
| KoreForge.Monitoring | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.OData | None yet | `doc/SecurityGuide.md` | `doc/UsageGuide.md` | None yet | None yet |
| KoreForge.Processing | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Scripts | `doc/Specification.md`, `doc/Main-Specification.md` | `doc/Implementation-Plan.md` | `README.md` | None yet | None yet |
| KoreForge.Settings | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Templates | None yet | None yet | `README.md`, template READMEs | None yet | Template folder layouts |
| KoreForge.Time | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Web | `doc/3. Specification.md` | `doc/2. Prompt and Analyzer.md` | `README.md` | None yet | `doc/1. Rough idea and specifications.md`, `doc/versioning-guide.md`, analyzer release manifests |
| KoreForge.SwaggerControllers | `doc/specification.md` | None yet | `doc/user-guide.md` | `doc/developer-guide.md` | `doc/structure.md`, `doc/notes/implementation-plan.md` |

## Tooling Repos

| Repo | Specification | Detailed design | User guide | Developer guide | Structure or notes |
| --- | --- | --- | --- | --- | --- |
| KoreForge.Jex.Cli | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Jex.LanguageServer | None yet | None yet | `README.md` | None yet | None yet |
| KoreForge.Jex.VSCodeExtension | None yet | None yet | `README.md`, `MARKETPLACE.md` | None yet | Extension package layout |
| KoreForge.NuGet.IntegrationTests | None yet | None yet | `README.md` | None yet | Contains copied docs under `doc/` and `docs/`; needs pruning or classification |

## Front-End Repos (eco-web)

| Repo | Specification | Detailed design | User guide | Developer guide | Structure or notes |
| --- | --- | --- | --- | --- | --- |
| KoreForge.Monitoring.Shell | `doc/specification.md` | None yet | `README.md` | None yet | None yet |
| KoreForge.Scripts.Vue | `doc/specification.md` | None yet | `README.md` | None yet | None yet |
| KoreForge.Jex.Vue | `doc/specification.md` | None yet | `README.md` | None yet | Implementation not started |
| KoreForge.Kafka.Vue | `doc/specification.md` | None yet | `README.md` | None yet | Implementation not started |

## Event Repos

| Repo | Specification | Detailed design | User guide | Developer guide | Structure or notes |
| --- | --- | --- | --- | --- | --- |
| Event.Benchmarks | None yet | None yet | None yet | None yet | None yet |
| Event.Processor | None yet | None yet | Copied AppLifecycle docs | Copied AppLifecycle docs | Needs Event-specific docs |
| Event.Reader | None yet | `EventReader-Message-Processing-Architecture.md` | Copied AppLifecycle docs | Copied AppLifecycle docs | Needs Event-specific docs |
| Event.Streaming | None yet | None yet | `README.md` | None yet | None yet |
| Event.Writer | `docs/configurable_json_to_sql_writer_spec.md` | None yet | None yet | None yet | None yet |
| Event.FraudIntegration.Data (private) | `doc/specification.md` | None yet | `README.md` | None yet | `doc/notes/implementation-plan.md` |
| EWorkspace-Cross-Cutting Specs

| Document | Type | Notes |
| --- | --- | --- |
| `docs/ecosystem/specifications/swagger-controllers.md` | Specification | 4-repo interaction: KoreForge.SwaggerControllers + Event.FraudIntegration.Data + Event.FraudIntegrationControllers + Event.ApiHost. |

## vent.FraudIntegrationControllers (private) | `doc/specification.md` | None yet | `README.md` | None yet | `doc/notes/implementation-plan.md` |
| Event.ApiHost | `doc/specification.md` | None yet | `README.md` | None yet | `doc/notes/implementation-plan.md` |

## Cleanup Priorities

1. Rename touched docs to canonical lowercase names during repo renovation.
2. Replace copied AppLifecycle docs in Event repos with Event-specific user/developer/structure docs.
3. Review `KoreForge.Jex/doc/README.md`; it appears to describe the VS Code extension rather than the JEX library repo.
4. Add missing `doc/specification.md` and `doc/user-guide.md` for small packages that currently only have `README.md`.
5. Move deeper historical notes into `doc/notes/` when they remain useful.
