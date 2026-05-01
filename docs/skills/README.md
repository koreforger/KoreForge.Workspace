# KoreForge Skills Catalog

These skills are workflow playbooks for humans and LLMs working in the KoreForge ecosystem. A skill is more than a command list: it names the goal, the repo context to inspect, the steps to perform, and the checks that prove the work is done.

## Skill List

| Skill | Use when | Primary references |
| --- | --- | --- |
| Workspace orientation | Entering the workspace, finding repos, or explaining ownership boundaries. | `README.md`, `docs/ecosystem/layout.md`, `docs/ecosystem/naming.md` |
| Package-only local development | Changing a package and validating consumers without project references. | `NuGet.config`, `scr/pack-local-feed.ps1`, `docs/ecosystem/build-and-release.md` |
| Add a KoreForge package repo | Creating a new `KoreForge.*` runtime package. | `packages/`, `docs/ecosystem/documentation-standard.md`, existing `scr/koreforge-build.psm1` |
| Renovate or rename a package repo | Retiring legacy `KF.*` names, updating projects, namespaces, packages, tests, and docs. | `docs/ecosystem/naming.md`, `docs/ecosystem/build-and-release.md` |
| Configure repo scripts for builder | Adding or repairing repo `scr/*.ps1` scripts so the workspace runner discovers them. | `builder.ps1`, `docs/ecosystem/Introduction/90-Tools-and-Scripts.md` |
| Use KoreForge templates | Installing, testing, or extending `dotnet new` templates. | `packages/KoreForge.Templates`, `docs/ecosystem/Introduction/53-Templates.md` |
| Add Event integration or stress tests | Adding realistic Event app validation against Kafka, SQL, and KoreForge packages. | `event/`, Event repo `scr/`, Docker docs |
| Coordinate package release | Packing all packages at one version and publishing from local or GitHub flows. | `scr/pack-all.ps1`, `scr/release-nuget-from-local.ps1`, `docs/ecosystem/build-and-release.md` |
| Maintain artifact discipline | Ensuring every generated file lands under root `artifacts/`. | `build.ps1`, `scr/clean-artifacts.ps1`, repo `scr/koreforge-build.psm1` |
| Maintain documentation | Classifying, renaming, and indexing docs according to the standard types. | `docs/README.md`, `docs/ecosystem/documentation-standard.md`, `docs/ecosystem/documentation-inventory.md` |
| Docker development infrastructure | Starting, resetting, and diagnosing local infrastructure. | `scr/docker-*.ps1`, `docs/development/docker.md`, `docker/docker-compose.yml` |

## Skill Shape

Each skill should answer these questions:

1. What problem does this skill solve?
2. Which repos and files should be inspected first?
3. What commands or scripts should be used?
4. What should never be done?
5. What validation proves the work is complete?
6. What artifacts or docs should be updated?

## Candidate Workspace Skills

These are good candidates for future `.github/skills/<name>/SKILL.md` files if we want LLMs to load them on demand:

| Candidate skill | Trigger phrases |
| --- | --- |
| `koreforge-package-development` | package-only development, local feed, pack consumer, no ProjectReference |
| `koreforge-repo-renovation` | rename namespace, retire KF, renovate package, update csproj/slnx |
| `koreforge-builder-scripts` | add script to builder, script discovery, build-test, build-pack |
| `koreforge-template-authoring` | dotnet template, template package, sample exclusion |
| `koreforge-release` | coordinated version, local NuGet release, GitHub publishing |
| `koreforge-docs-standard` | documentation standard, classify docs, write specification/user guide |
| `event-integration-testing` | Event.Reader, stress tests, Kafka fixture, integration reports |
| `koreforge-docker-infra` | docker up, docker reset, SQL bootstrap, Kafka readiness |

## Current Decisions Captured By Skills

- Use package references only. Do not add `ProjectReference`.
- Use root `artifacts/` for generated output.
- Use `builder.ps1` for interactive script discovery.
- Use `build.ps1` for the simple front door and artifact cleanup switches.
- Use `1.0.1-alpha` for local publish tests, incrementing the patch number for repeated tests.
- Use `main` as the stable branch and `development` as the active branch.
- Prefer fixing Docker/bootstrap readiness at the infrastructure layer over adding production runtime retries.
