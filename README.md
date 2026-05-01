# KoreForge Workspace

This repository is the workspace shell for the KoreForge ecosystem. It contains almost no product code. Its job is to document, clone, build, test, package, and release the repos that make up KoreForge and the Event test applications.

## Layout

```text
packages/   KoreForge NuGet package repos. Repo/package names use KoreForge.*. Assemblies use KF.*.
tools/      Developer tooling repos, including JEX CLI, language server, VS Code extension, and package integration tests.
npm/        Reusable npm/Vue packages and the planned monitoring shell.
event/      Event.* test applications and Event-owned shared libraries. These validate KoreForge in real app scenarios.
docs/       Ecosystem documentation, standards, proposals, and archived notes.
scr/        Workspace-level orchestration scripts.
.local/     Ignored local secrets and machine-specific files.
```

## Rules

1. Package repos are independent repos and publish independently.
2. NuGet package level uses `KoreForge.*`; DLL/assembly level uses `KF.*`.
3. Event-owned code uses `Event.*`, never `KoreForge.*`.
4. No `.csproj` file uses `ProjectReference`. Development consumes local NuGet packages from `.artifacts/packages`.
5. Every buildable repo exposes standard scripts under `scr/`.
6. Test, coverage, benchmark, and runtime output goes under ignored output folders.
7. Docker development infrastructure is documented under `docs/development/docker.md` and should be started through scripts, not hand-built steps.

## First Setup

```powershell
.\setup-koreforge.ps1 -Root C:\My\KoreForge2
```

The setup script verifies required tools, creates local folders, checks out missing repos when configured, and prepares the local package feed.

## Daily Workflow

Run the script runner from the workspace root:

```powershell
.\builder-v5.ps1
```

Use it to select any repo's `Clean`, `Rebuild`, `Test`, `Coverage`, `Integration`, `Benchmark`, or `Pack` action. Logs are written under `.artifacts/script-runner/logs`.

## Local Package Development

Local development is package-based:

1. Change a package repo.
2. Run its `scr/build-test.ps1`.
3. Run its `scr/build-pack.ps1 -Version 1.0.1-alpha`.
4. Copy/package output into `.artifacts/packages` or use the workspace pack script.
5. Build consuming apps against the local package feed.

Use `1.0.1-alpha`, then increment the final number for repeated publishing tests: `1.0.2-alpha`, `1.0.3-alpha`, and so on.

## Important Documentation

- [Ecosystem layout](docs/ecosystem/layout.md)
- [Naming standard](docs/ecosystem/naming.md)
- [Build and release workflow](docs/ecosystem/build-and-release.md)
- [Docker development](docs/development/docker.md)
- [Monitoring shell specification](docs/ecosystem/monitoring-shell-spec.md)
