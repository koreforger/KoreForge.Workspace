# KoreForge Developer Guide

> **Version**: 0.0.6-alpha · **.NET 10** · MIT License
> Packages on [nuget.org/profiles/koreforger](https://www.nuget.org/profiles/koreforger)

This guide is maintained as individual pages in `doc/Introduction/`. Run `Export-documentation.ps1` to produce a single combined file.

## Document Index

### Foundation

| Document | Description |
|----------|-------------|
| [00-Introduction](Introduction/00-Introduction.md) | Ecosystem overview: what, why, how, package inventory |
| [01-Architecture](Introduction/01-Architecture.md) | Design principles, layer model, dependency graph, conventions |

### Infrastructure Layer

| Document | Description |
|----------|-------------|
| [10-Time](Introduction/10-Time.md) | Clock abstraction (`IClock`) |
| [11-Jex](Introduction/11-Jex.md) | JSON Expression Language DSL |
| [11a-Jex-Cli](Introduction/11a-Jex-Cli.md) | JEX CLI tool |
| [11b-Jex-VSCode](Introduction/11b-Jex-VSCode.md) | VS Code extension |
| [11c-Jex-LanguageServer](Introduction/11c-Jex-LanguageServer.md) | Language Server Protocol |
| [12-Json](Introduction/12-Json.md) | JSON materializer, classifier, JEX bridge |

### Observability Layer

| Document | Description |
|----------|-------------|
| [20-Metrics](Introduction/20-Metrics.md) | Bounded in-memory metrics |
| [20a-Metrics-AspNet](Introduction/20a-Metrics-AspNet.md) | ASP.NET Core metrics endpoint |
| [21-Logging](Introduction/21-Logging.md) | Source-generated structured logging |
| [21a-Logging-Serilog](Introduction/21a-Logging-Serilog.md) | Serilog integration |

### Domain Layer

| Document | Description |
|----------|-------------|
| [30-Processing](Introduction/30-Processing.md) | Pipelines and Flows |
| [31-AppLifecycle](Introduction/31-AppLifecycle.md) | Startup, shutdown, scheduled flows |

### Application Layer

| Document | Description |
|----------|-------------|
| [40-Kafka](Introduction/40-Kafka.md) | Consumer, producer, admin client |
| [41-Web](Introduction/41-Web.md) | REST API framework, authorization, audit |

### Data / Config Layer

| Document | Description |
|----------|-------------|
| [50-Settings](Introduction/50-Settings.md) | SQL-backed live-reload configuration |
| [52-OData](Introduction/52-OData.md) | Source-generated OData controllers |
| [53-Templates](Introduction/53-Templates.md) | `dotnet new` project scaffolding |

### Reference

| Document | Description |
|----------|-------------|
| [90-Tools-and-Scripts](Introduction/90-Tools-and-Scripts.md) | All bin scripts, CLI tools, Docker scripts |

## API Reference

Auto-generated API docs are in `doc/Api/`. See the combined documentation file for the full content.

## Generating Combined Documentation

`powershell
.\KoreForge.Main\scr\Export-documentation.ps1
`

This produces `KoreForge-Documentation.md` at the workspace root with all Introduction and API docs concatenated.
