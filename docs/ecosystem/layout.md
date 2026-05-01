# Workspace Layout

KoreForge uses a grouped multi-repo workspace. The grouping makes the workspace easier to scan while preserving independent package repositories and release cadence.

## Root

The root folder is the workspace shell. It contains orchestration scripts, documentation, setup, local configuration, and no product code.

## packages

`packages/` contains NuGet-producing KoreForge repos. Repo, project, package, assembly, and namespace names use `KoreForge.*`.

Examples:

```text
packages/KoreForge.Settings/src/KoreForge.Settings/KoreForge.Settings.csproj
packages/KoreForge.Kafka/src/KoreForge.Kafka.Consumer/KoreForge.Kafka.Consumer.csproj
```

## tools

`tools/` contains developer tooling and validation harnesses:

- JEX CLI
- JEX language server
- JEX VS Code extension
- NuGet integration tests

## npm

`npm/` contains publishable npm packages and frontend shells:

- `KoreForge.Scripts.Vue`
- `KoreForge.Monitoring.Shell`
- future `KoreForge.Jex.Vue` and `KoreForge.Kafka.Vue`

## event

`event/` contains Event-owned test applications and libraries. These are not KoreForge packages; they prove KoreForge works in real applications.

- `Event.Streaming`
- `Event.Processor`
- `Event.Reader`
- `Event.Benchmarks`
- `Event.Writer`

## Dependency Rule

Projects do not use `ProjectReference`. All cross-project dependencies flow through NuGet packages, including local development. The workspace `NuGet.config` points at `artifacts/packages` before nuget.org.

All generated output belongs under the root `artifacts/` folder. Child repos should not create repo-local `artifacts/`, `out/`, `TestResults/`, coverage, report, or benchmark output folders.
