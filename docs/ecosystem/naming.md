# Naming Standard

## KoreForge Packages

| Layer | Pattern | Example |
|---|---|---|
| Repository folder | `KoreForge.Area` | `KoreForge.Settings` |
| NuGet package | `KoreForge.Area` for public package families | `KoreForge.Settings` |
| Assembly / DLL | `KF.Area` | `KF.Settings.Core` |
| Test assembly | `KF.Area.Tests` | `KF.Settings.Tests` |
| Namespace | `KF.Area` | `KF.Settings.Core` |

Some package families produce several DLLs. The repo/package family remains `KoreForge.*`; DLLs remain `KF.*`.

## Event Test Apps

Event code is not KoreForge code. Event repos, packages, and assemblies should use `Event.*` for shared libraries and app package identities.

Examples:

```text
event/Event.Streaming/src/Event.Streaming.Processing
event/Event.Reader
event/Event.Processor
```

Class names may still use readable app-specific names such as `EventReaderKafkaBatchProcessor`; do not force dotted namespace style into type names.

## Tooling

JEX tooling is grouped under `tools/` but should use KoreForge repo names for clarity:

```text
tools/KoreForge.Jex.Cli
tools/KoreForge.Jex.LanguageServer
tools/KoreForge.Jex.VSCodeExtension
```

Assemblies may remain `KF.Jex.*` where that is the established DLL convention.
