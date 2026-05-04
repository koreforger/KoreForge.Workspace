# KoreForge

> **.NET 10** · MIT License
> Packages on [nuget.org/profiles/koreforger](https://www.nuget.org/profiles/koreforger)

## What is KoreForge?

KoreForge is an ecosystem of .NET libraries that eliminates repetitive infrastructure code from your applications. Instead of every team re-implementing logging setup, metrics collection, configuration management, Kafka integration, OData endpoints, and application lifecycle — KoreForge solves each of these problems once, thoroughly, and makes the solution available as a NuGet package.

The core philosophy is simple: **if a problem has been solved, it stays solved.** You should spend your time writing business logic, not wiring up the same boilerplate for the hundredth time.

## Why an Ecosystem?

A single monolithic library would force you to take everything or nothing. KoreForge is deliberately structured as independent packages that can be adopted individually or together:

- **Need just a clock abstraction?** Install `KoreForge.Time` — nothing else comes with it.
- **Need Kafka consumers with observability?** Install `KoreForge.Kafka` — it pulls in metrics and logging automatically.
- **Building a full application?** Use `dotnet new koreforge-kafka-processor` to scaffold an entire solution with all conventions pre-applied.

Each package has minimal dependencies, clear boundaries, and its own release cycle.

## Problems Solved

### Boilerplate Elimination

Every enterprise .NET application eventually needs: structured logging with event IDs, in-memory metrics, health checks, resilient Kafka consumers, live-reload configuration, OData endpoints, application startup/shutdown orchestration, and processing pipelines. Without KoreForge, each team builds these from scratch.

### Consistency

When five teams build five Kafka consumers, you get five different approaches to error handling, backpressure, and metrics. KoreForge provides one well-tested implementation that every consumer shares.

### Solved-Once Guarantee

Bug fixes and improvements flow to every application through package updates. Fix a Kafka consumer edge case once, and every application gets the fix on their next update.

### Testability

Every KoreForge component is designed for unit testing. Clocks are injectable, metrics are queryable, settings reload is deterministic, and message handlers can be tested without a running broker.

## How to Use KoreForge

### As Individual Libraries

Install only what you need:

```bash
dotnet add package KoreForge.Time
dotnet add package KoreForge.Metrics
dotnet add package KoreForge.Settings
```

### As an Ecosystem

Use the full stack for maximum benefit. The packages are designed to work together — Kafka consumers emit metrics through `KoreForge.Metrics`, lifecycle management uses `KoreForge.Processing` flows, settings hot-reload integrates with .NET `IConfiguration`.

### From Templates

Scaffold a complete application:

```bash
dotnet new install KoreForge.Templates
dotnet new koreforge-kafka-processor -n MyApp --KafkaTopic orders
```

## Package Inventory

| # | Package | Purpose | Layer |
|---|---------|---------|-------|
| 1 | `KoreForge.Time` | Clock abstraction (`IClock`) | Infrastructure |
| 2 | `KoreForge.Jex` | JSON Expression Language (DSL) | Infrastructure |
| 3 | `KoreForge.Json` | JSON materializer, root classification, JEX bridge | Infrastructure |
| 4 | `KoreForge.Metrics` | Bounded in-memory metrics, `IOperationMonitor` | Observability |
| 5 | `KoreForge.Metrics.AspNet` | ASP.NET Core metrics endpoint | Observability |
| 6 | `KoreForge.Logging` | Source-generated structured logging from enums | Observability |
| 7 | `KoreForge.Logging.Serilog` | Serilog sink integration | Observability |
| 8 | `KoreForge.Processing` | Pipelines and Flows | Domain |
| 9 | `KoreForge.AppLifecycle` | Startup, shutdown, scheduled flows | Domain |
| 10 | `KoreForge.Kafka` | Consumer, producer, admin client | Application |
| 11 | `KoreForge.Web` | REST API framework, authorization, audit | Application |
| 12 | `KoreForge.Settings` | SQL-backed live-reload configuration | Data / Config |
| 13 | `KoreForge.OData` | Source-generated OData controllers | Data / Config |
| 14 | `KoreForge.Data` | EF Core database-first scaffolding | Data / Config |
| 15 | `KoreForge.Templates` | `dotnet new` project scaffolding | Tooling |

## Versioning

All packages use [MinVer](https://github.com/adamralph/minver) for git tag-driven versioning. Tags follow the pattern `{Prefix}/v{Version}` (e.g. `Kafka/v0.0.6-alpha`). Pushing a tag triggers the GitHub Actions Trusted Publishing workflow, which packs and publishes to NuGet.org.

## Target Framework

All packages target **.NET 10 (`net10.0`)**. The OData source generator targets `netstandard2.0` (Roslyn requirement).

## License

All KoreForge packages are released under the [MIT License](https://opensource.org/licenses/MIT).
