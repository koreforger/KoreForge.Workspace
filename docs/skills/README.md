# KoreForge Skills Catalog

These skills are workflow playbooks for humans and LLMs working in the KoreForge ecosystem. A skill is more than a command list: it names the goal, the repo context to inspect, the steps to perform, and the checks that prove the work is done.

Copilot-wide workspace rules live in `.github/copilot-instructions.md`. Concrete on-demand skill files live under `.github/skills/<skill-name>/SKILL.md`.

## Skill List

| Skill | Use when | Skill file |
| --- | --- | --- |
| Package-only local development | Changing a package and validating consumers without project references or vendored source. | `.github/skills/koreforge-package-development/SKILL.md` |
| Add a new project or repo | Creating a new package, tool, npm package, or Event app and wiring it into the workspace. | `.github/skills/koreforge-new-project/SKILL.md` |
| Renovate or rename a package repo | Retiring legacy `KoreForge.*` names, updating projects, namespaces, packages, tests, and docs. | `.github/skills/koreforge-repo-renovation/SKILL.md` |
| Configure repo scripts for builder | Adding or repairing repo `scr/*.ps1` scripts so the workspace runner discovers them. | `.github/skills/koreforge-builder-scripts/SKILL.md` |
| Use KoreForge templates | Installing, testing, or extending `dotnet new` templates. | `.github/skills/koreforge-template-authoring/SKILL.md` |
| Add Event integration or stress tests | Adding realistic Event app validation against Kafka, SQL, and KoreForge packages. | `.github/skills/event-integration-testing/SKILL.md` |
| Coordinate package release | Packing all packages at one version and publishing from local or GitHub flows. | `.github/skills/koreforge-release/SKILL.md` |
| Maintain documentation | Classifying, renaming, and indexing docs according to the standard types. | `.github/skills/koreforge-docs-standard/SKILL.md` |
| Docker development infrastructure | Starting, resetting, and diagnosing local infrastructure. | `.github/skills/koreforge-docker-infra/SKILL.md` |

## Skill Shape

Each skill should answer these questions:

1. What problem does this skill solve?
2. Which repos and files should be inspected first?
3. What commands or scripts should be used?
4. What should never be done?
5. What validation proves the work is complete?
6. What artifacts or docs should be updated?

## Candidate Workspace Skills

These are implemented under `.github/skills/<name>/SKILL.md` so LLMs can load them on demand:

| Candidate skill | Trigger phrases |
| --- | --- |
| `koreforge-package-development` | package-only development, local feed, pack consumer, no ProjectReference |
| `koreforge-new-project` | add project, configure repo, builder.config.json, new package, new Event app |
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
