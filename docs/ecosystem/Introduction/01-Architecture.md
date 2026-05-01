# KoreForge — Architecture

## Design Principles

Five rules govern every KoreForge library. They are not aspirational — they are enforced by code review, tests, and analyzers.

**Config-only.** Every library is configured entirely through `IServiceCollection` registration and `IConfiguration` binding. No environment variables are read directly. No magic conventions. No implicit defaults that depend on the hosting environment. If a value matters, it is an explicit parameter.

**Observable by default.** Every significant operation emits structured logs and metrics out of the box. You do not need to wrap KoreForge calls in your own instrumentation. Logs use source-generated event IDs with hierarchical numbering. Metrics use bounded in-memory collectors that can be scraped via HTTP endpoint.

**Composable.** Libraries interact through interfaces, not concrete types. `ISystemClock`, `IOperationMonitor`, `ISettingsService`, `IKafkaBatchProcessor` — these are contracts. You can replace any implementation. You can test against fakes. You can swap one library for another behind the same interface.

**Testable.** Every library ships with patterns for deterministic unit testing. `VirtualSystemClock` for time. SQLite in-memory for EF Core contexts. In-memory configuration for settings. If a library cannot be tested without external infrastructure (a real database, a real Kafka broker), that is a design failure.

**Fail-fast.** Configuration errors, missing dependencies, bad connection strings — these surface at startup, not at 2am when the first request arrives. Libraries validate their options eagerly and throw descriptive exceptions during DI registration or application start.

## Layer Model

KoreForge is organized in four layers. Lower layers have no knowledge of higher layers. Dependencies flow strictly downward.

```
┌──────────────────────────────────────────────────────┐
│  APPLICATION                                         │
│  Kafka · Web                                         │
├──────────────────────────────────────────────────────┤
│  DOMAIN                                              │
│  Processing · AppLifecycle                           │
├──────────────────────────────────────────────────────┤
│  OBSERVABILITY                                       │
│  Logging · Logging.Serilog · Metrics · Metrics.AspNet│
├──────────────────────────────────────────────────────┤
│  INFRASTRUCTURE                                      │
│  Time · Jex · Json · Settings · Data · OData         │
└──────────────────────────────────────────────────────┘
```

### Infrastructure (zero or minimal KoreForge dependencies)

| Library | Depends On |
|---------|-----------|
| Time | Nothing |
| Jex | Nothing |
| Json | Nothing |
| Settings | Nothing (uses EF Core internally) |
| Data | Nothing (uses EF Core) |
| OData | Nothing (Roslyn source generator at compile time) |

### Observability (depends on Infrastructure)

| Library | Depends On |
|---------|-----------|
| Metrics | Time |
| Logging | Metrics, Time |
| Logging.Serilog | Logging |
| Metrics.AspNet | Metrics |

### Domain (depends on Observability or nothing)

| Library | Depends On |
|---------|-----------|
| Processing | Microsoft.Extensions.* only |
| AppLifecycle | Processing |

### Application (depends on Domain + Observability)

| Library | Depends On |
|---------|-----------|
| Kafka | Processing, Metrics, Logging, Time |
| Web | Metrics, Logging, Time |

## Dependency Graph

```
KoreForge.Time ──────────────────┐
                                 ├─→ KoreForge.Metrics ──┐
KoreForge.Jex (standalone)       │                        ├─→ KoreForge.Logging ──→ Logging.Serilog
KoreForge.Json (standalone)      │                        │
                                 │    Metrics.AspNet ◄────┘
KoreForge.Settings (standalone)  │
KoreForge.Data (standalone)      │
KoreForge.OData (standalone)     │
                                 │
KoreForge.Processing ────────────┼─→ KoreForge.AppLifecycle
                                 │
                                 └─→ KoreForge.Kafka ◄── Processing + Metrics + Logging + Time
                                     KoreForge.Web   ◄──          Metrics + Logging + Time
```

## Orchestration Patterns

KoreForge provides two distinct orchestration patterns through `KoreForge.Processing`. The choice between them depends on the shape of the work.

### Pipelines — Linear Data Transformation

A pipeline takes an input, passes it through a sequence of steps, and produces an output. Each step receives the output of the previous step and returns a new type.

```
Input → Step1 → Step2 → Step3 → Output
         ↓        ↓        ↓
      TIn→T1    T1→T2    T2→TOut
```

Use when: each step produces a new type, the work is data transformation, you are processing Kafka message batches.

### Flows — State-Machine Orchestration

A flow passes a shared context through stages. Each stage reads and writes to the same context object.

```
Context → Stage1 → Stage2 → Stage3
            ↓         ↓         ↓
         mutates   mutates   mutates
         context   context   context
```

Use when: stages share a mutable context, the work is a business process, stages need results from siblings, outcomes determine branching.

## Standard Repository Layout

Every `KoreForge.*` repository follows the same directory structure:

```
KoreForge.{Library}/
├── Directory.Build.props        # Build properties, MinVer config
├── Directory.Packages.props     # Central Package Management
├── KoreForge.{Library}.slnx      # Solution file
├── README.md
├── LICENSE.md
├── scr/                         # PowerShell automation scripts
├── doc/                         # Specifications, guides
├── src/KF.{Lib}/                # Source project(s)
└── tst/KF.{Lib}.Tests/          # Test project(s)
```

## Naming Conventions

| Concept | Pattern | Example |
|---------|---------|---------|
| Repository folder | `KoreForge.{Area}` | `KoreForge.Kafka` |
| NuGet package ID | `KoreForge.{Area}` | `KoreForge.Kafka` |
| Source project | `KF.{Area}` | `KF.Kafka.Consumer` |
| Test project | `KF.{Area}.Tests` | `KF.Kafka.Tests` |
| DI extension class | `{Area}ServiceCollectionExtensions` | `KafkaServiceCollectionExtensions` |
| Options class | `{Area}Options` | `KafkaConsumerOptions` |

## Testing Standards

| Rule | Detail |
|------|--------|
| Naming | `{Method}_{Scenario}_{Expected}` |
| Structure | Arrange / Act / Assert |
| Time | Always `VirtualSystemClock`, never `DateTime.Now` |
| Coverage | ≥ 70% line coverage |
| Framework | xUnit + `Microsoft.NET.Test.Sdk` |
