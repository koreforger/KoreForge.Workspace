# KoreForge Documentation

> Auto-generated: 2026-04-14 23:20:56

---

# KoreForge

> **Version**: 0.0.6-alpha · **.NET 10** · MIT License
> Packages on [nuget.org/profiles/koreforger](https://www.nuget.org/profiles/koreforger)

## What is KoreForge?

KoreForge is an ecosystem of .NET libraries that eliminates repetitive infrastructure code from your applications. Instead of every team re-implementing logging setup, metrics collection, configuration management, Kafka integration, OData endpoints, and application lifecycle — KoreForge solves each of these problems once, thoroughly, and makes the solution available as a NuGet package.

The core philosophy is simple: **if a problem has been solved, it stays solved.** You should spend your time writing business logic, not wiring up the same boilerplate for the hundredth time.

## Why an Ecosystem?

A single monolithic library would force you to take everything or nothing. KoreForge is deliberately structured as independent packages that can be adopted individually or together:

- **Need just a clock abstraction?** Install `KoreForge.Time` — nothing else comes with it.
- **Need Kafka consumers with observability?** Install `KF.Kafka` — it pulls in metrics and logging automatically.
- **Building a full application?** Use `dotnet new kf-kafka-processor` to scaffold an entire solution with all conventions pre-applied.

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
dotnet new kf-kafka-processor -n MyApp --KafkaTopic orders
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

---

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

---

# KoreForge.Time

| | |
|---|---|
| **Package** | `KoreForge.Time` |
| **Namespace** | `KF.Time` |
| **Source** | `KoreForge.Time/src/KF.Time/` |
| **Tests** | `KoreForge.Time/tst/KF.Time.Tests/` |
| **Dependencies** | None |

## Problem

Production code that calls `DateTime.Now` or `DateTimeOffset.UtcNow` directly is untestable. You cannot write a deterministic test that asserts "this cache entry expires in 5 minutes" when the clock advances unpredictably between assertions. You also cannot reproduce time-dependent bugs.

## Solution

KoreForge.Time provides `ISystemClock` — an interface with a single `Now` property that returns `DateTimeOffset`. Three implementations ship:

- `UtcSystemClock` — wraps `DateTimeOffset.UtcNow`. Use in production for UTC-based systems.
- `LocalSystemClock` — wraps `DateTimeOffset.Now`. Use when local time zone matters.
- `VirtualSystemClock` — a manually-controlled clock for tests. You set the time, advance it, and assert against it.

## Compromises

- One more interface to inject instead of calling `DateTime.Now` directly.
- `VirtualSystemClock` prevents backward time travel by design — calling `Advance()` with a negative span throws. This protects against accidental test setup errors but means you cannot simulate clock drift.

## Installation

```bash
dotnet add package KoreForge.Time
```

## DI Registration

```csharp
// Production — UTC clock
builder.Services.AddSingleton<ISystemClock, UtcSystemClock>();

// Production — local time zone clock
builder.Services.AddSingleton<ISystemClock, LocalSystemClock>();
```

## Configuration

No configuration options. The clock is stateless.

## API Reference

### `ISystemClock`

```csharp
public interface ISystemClock
{
    DateTimeOffset Now { get; }
}
```

### `UtcSystemClock`

Returns `DateTimeOffset.UtcNow`. Suitable for all server-side code.

### `LocalSystemClock`

Returns `DateTimeOffset.Now` in the host machine's time zone.

### `VirtualSystemClock`

```csharp
public class VirtualSystemClock : ISystemClock
{
    public VirtualSystemClock(DateTimeOffset? startTime = null);
    public DateTimeOffset Now { get; }
    public void Advance(TimeSpan duration);    // duration must be non-negative
    public void Set(DateTimeOffset time);      // must not be before current Now
}
```

## Examples

### Production usage

```csharp
public class CacheService(ISystemClock clock)
{
    public bool IsExpired(DateTimeOffset cachedAt, TimeSpan ttl)
        => clock.Now - cachedAt > ttl;
}
```

### Test usage

```csharp
[Fact]
public void IsExpired_AfterTtl_ReturnsTrue()
{
    var clock = new VirtualSystemClock(DateTimeOffset.Parse("2025-01-01T00:00:00Z"));
    var service = new CacheService(clock);

    var cachedAt = clock.Now;
    clock.Advance(TimeSpan.FromMinutes(6));

    Assert.True(service.IsExpired(cachedAt, TimeSpan.FromMinutes(5)));
}
```

---

# KoreForge.Jex

| | |
|---|---|
| **Package** | `KoreForge.Jex` |
| **Namespace** | `KoreForge.Jex` |
| **Source** | `KoreForge.Jex/src/KF.Jex/` |
| **Tests** | `KoreForge.Jex/tst/KF.Jex.Tests/` |
| **Dependencies** | None |

## Problem

Enterprise systems process millions of JSON messages daily. Each message needs to be transformed — fields renamed, nested objects flattened, arrays filtered, escaped JSON strings expanded. Doing this in C# means writing hundreds of lines of `JsonDocument` traversal code per message type. When the schema changes, the C# code changes. When a new field mapping is needed, a developer must modify, test, build, and deploy.

## Solution

JEX (JSON Expression Language) is a purpose-built DSL for JSON-to-JSON transformation. A JEX script defines the output structure declaratively: each key maps to an output field, and values are JEX expressions that extract, combine, or compute values from the input. Scripts are text files that can be authored, tested, and deployed independently of the application.

JEX is compiled once and executed many times. The runtime uses System.Text.Json internally. The language is intentionally limited — no I/O, no side effects, no external service calls. A JEX script is a pure function: JSON in, JSON out.

## Compromises

- JEX is a new language to learn. It is simpler than JSONata or jq, but it is still a DSL.
- The language is deliberately limited. You cannot make HTTP calls, write to disk, or generate random values from a JEX script. This is by design — safety and determinism are non-negotiable.
- Complex multi-step transformations may be harder to debug than equivalent C# code because the intermediate state is not visible in a standard debugger (use the VS Code preview panel instead).

## Installation

```bash
dotnet add package KoreForge.Jex
```

## DI Registration

```csharp
builder.Services.AddJex();
```

Or use directly without DI:

```csharp
var jex = new Jex();
```

## Configuration

No configuration options. JEX is stateless.

## API Reference

### `Jex` class

```csharp
public class Jex
{
    // Transform a single JSON input using a JEX script
    public string Transform(string transform, string inputJson);
    public string Transform(string transform, JsonDocument inputDoc);

    // Transform multiple inputs using the same script
    public IEnumerable<string> TransformMany(string transform, IEnumerable<string> inputs);
}
```

### `JexException`

Thrown when a script contains syntax errors or a runtime error occurs during transformation.

## Expression Syntax

| Syntax | Purpose | Example |
|--------|---------|---------|
| `$in.path.to.field` | Field access | `$in.customer.name` |
| `$in.items[0].name` | Array index | `$in.orders[0].total` |
| `"Hello $in.name"` | String interpolation | `"Order #$in.id"` |
| `$in.age >= 18` | Boolean expression | `$in.total > 100` |
| `$in.subtotal * 1.2` | Arithmetic | `$in.price * $in.qty` |
| `$if / $then / $else` | Conditional | see examples |
| `$spread` | Object projection | Copies all fields |
| `$map` | Array mapping | Transform each element |
| `$filter` | Array filter | Select matching elements |
| `$coalesce` | Null coalescing | First non-null value |

## Examples

### Simple field mapping

```
// transform.jex
{
  "fullName": "$in.first_name + ' ' + $in.last_name",
  "email": "$in.contact.email",
  "isActive": "$in.status == 'active'"
}
```

### Conditional logic

```
{
  "tier": "$if $in.total > 1000 $then 'gold' $else 'standard'"
}
```

### Array transformation

```
{
  "orderIds": "$map $in.orders => $item.id",
  "expensiveOrders": "$filter $in.orders => $item.total > 100"
}
```

### With metadata

```csharp
var jex = new Jex();
string result = jex.Transform(script, input);
```

## See Also

- [11-Jex-Cli.md](11-Jex-Cli.md) — Command-line interface for JEX
- [12-Jex-VSCode.md](12-Jex-VSCode.md) — VS Code extension with preview panel
- [13-Jex-LanguageServer.md](13-Jex-LanguageServer.md) — LSP for editor integration
- `KoreForge.Jex/doc/Specification.md` — Full language specification

---

# KF.Jex.Cli — JEX Command-Line Interface

| | |
|---|---|
| **Tool** | `jex` (standalone executable) |
| **Source** | `KF.Jex.Cli/src/` |
| **Type** | .NET tool / standalone binary |
| **Dependencies** | KoreForge.Jex |

## Problem

JEX scripts need to be tested and iterated on outside of a running application. Waiting for a build-deploy cycle to verify a JSON transformation is slow and discourages experimentation.

## Solution

The JEX CLI is a command-line tool that executes JEX scripts directly from the terminal. It reads a `.jex` script file, auto-discovers or accepts an input JSON file, and writes the transformed output to stdout or a file. Watch mode re-runs the transform whenever the script or input changes.

## Compromises

- Requires .NET 10 runtime installed (unless using the self-contained build).
- Watch mode uses filesystem polling, not native file watchers — there may be a short delay on some platforms.

## Installation

### Build from source

```powershell
cd KF.Jex.Cli
.\scr\build-rebuild.ps1
```

### Standalone publish

```bash
dotnet publish -c Release -r win-x64 --self-contained
```

## Usage

### NAME

`jex` — execute a JEX transformation script

### SYNOPSIS

```
jex <script.jex> [--input <file>] [--output <file>] [--format <fmt>] [--meta <file>] [--watch]
```

### OPTIONS

| Option | Description | Default |
|--------|-------------|---------|
| `<script.jex>` | Path to JEX script file | Required |
| `--input <file>` | Path to input JSON file | Auto-discovered (see below) |
| `--output <file>` | Write result to file instead of stdout | stdout |
| `--format json` | Compact JSON output | `json` |
| `--format pretty` | Pretty-printed JSON | |
| `--format detailed` | Metadata + output + variables + timing | |
| `--meta <file>` | Metadata JSON accessible via `$meta` | None |
| `--watch` | Re-run on file changes | Off |

### INPUT FILE CONVENTION

If `--input` is not specified, the CLI looks for a companion file named `{script-name}.input.json` in the same directory as the script.

| Script file | Auto-discovered input |
|------------|----------------------|
| `transform.jex` | `transform.input.json` |
| `orders/flatten.jex` | `orders/flatten.input.json` |

### EXAMPLES

```bash
# Run with auto-discovered input
jex transform.jex

# Explicit input file
jex transform.jex --input data.json

# Pretty output
jex transform.jex --format pretty

# Write to file
jex transform.jex --output result.json

# Watch mode — re-run on any change
jex transform.jex --watch

# With metadata (accessible as $meta in script)
jex transform.jex --meta config.json
```

### METADATA

When `--meta` is provided, the metadata JSON is available in the script via `$meta`:

```
// In the JEX script
%let env = jp1($meta, "$.environment");
```

### EXIT CODES

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Script error (syntax or runtime) |
| 2 | File not found |

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [12-Jex-VSCode.md](12-Jex-VSCode.md) — VS Code extension

---

# KF.Jex.VSCode — VS Code Extension

| | |
|---|---|
| **Extension** | `KF.Jex.VSCode` |
| **Source** | `KF.Jex.VSCode/` |
| **Marketplace** | (not yet published) |
| **Requirements** | VS Code 1.85+, .NET 10 Runtime |

## Problem

Writing JEX scripts in a plain text editor provides no feedback until you run the CLI. Syntax errors are discovered at execution time. There is no autocomplete for JEX expressions, no inline documentation, and no way to see the transform result without switching to a terminal.

## Solution

The VS Code extension provides full language support for `.jex` files: syntax highlighting via TextMate grammar, real-time diagnostics from the Language Server, code completion, hover information, and an interactive preview panel that shows the transformation result live as you type.

## Compromises

- Requires .NET 10 runtime for the Language Server process.
- The preview panel re-executes the full transform on every save — large scripts with large inputs may show a brief delay.

## Installation

Install from the VS Code Extensions marketplace or from a `.vsix` file:

```bash
code --install-extension kf-jex-vscode-0.0.1.vsix
```

## Features

| Feature | Description |
|---------|-------------|
| Syntax highlighting | Full TextMate grammar for JEX keywords, expressions, strings, comments |
| Language Server | Real-time syntax error diagnostics, code completion, hover info |
| Script runner | Execute the current `.jex` file directly from the editor |
| Interactive preview | Side-by-side input/output panel with auto-run on save |
| Snippets | `let`, `set`, `if`, `foreach`, `func` |

## Commands

| Command | Shortcut | Description |
|---------|----------|-------------|
| JEX: Run Script | `Ctrl+Shift+R` | Execute the current script and show output |
| JEX: Run Script with Input... | — | Run with a custom input file (file picker) |
| JEX: Show Preview Panel | `Ctrl+Shift+P` | Open the interactive input/output preview |
| JEX: Create Input File | — | Create a `.input.json` companion file |
| JEX: Show Output | — | Show the JEX output channel |

## Configuration

Settings in VS Code `settings.json`:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `jex.languageServer.enabled` | boolean | `true` | Enable the JEX Language Server |
| `jex.languageServer.path` | string | bundled | Custom path to Language Server binary |
| `jex.cli.path` | string | bundled | Custom path to JEX CLI binary |
| `jex.preview.autoRun` | boolean | `true` | Auto-run transform when script/input is saved |

## File Conventions

The extension follows the same input file convention as the CLI:

| Script | Auto-discovered input |
|--------|----------------------|
| `transform.jex` | `transform.input.json` |

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [11a-Jex-Cli.md](11a-Jex-Cli.md) — JEX CLI tool
- [11c-Jex-LanguageServer.md](11c-Jex-LanguageServer.md) — Language Server internals

---

# KF.Jex.LanguageServer — JEX Language Server Protocol

| | |
|---|---|
| **Package** | `KF.Jex.LanguageServer` |
| **Source** | `KF.Jex.LanguageServer/src/` |
| **Tests** | `KF.Jex.LanguageServer/tst/` |
| **Protocol** | Language Server Protocol (LSP) over stdio |
| **Dependencies** | KoreForge.Jex, OmniSharp.Extensions.LanguageServer |

## Problem

Editor integrations for a custom DSL like JEX need a standardized protocol to provide diagnostics, completions, and hover information. Implementing these features separately for each editor (VS Code, Rider, Vim) duplicates effort.

## Solution

The JEX Language Server implements the Language Server Protocol (LSP), which is supported by most modern editors. It runs as a separate process communicating over stdio. The VS Code extension bundles and launches it automatically, but it can also be used standalone with any LSP-compatible editor.

## Compromises

- Requires .NET 10 runtime on the developer machine.
- Runs as a separate process — adds memory overhead compared to an in-process extension.

## Building

```powershell
cd KF.Jex.LanguageServer
.\scr\build-rebuild.ps1         # Build
.\scr\build-test.ps1          # Run tests
```

## Architecture

```
VS Code ←── stdio ──→ KF.Jex.LanguageServer
                           │
                           ├── TextDocumentSyncHandler (tracks open files)
                           ├── DiagnosticsHandler (syntax errors)
                           ├── CompletionHandler (autocomplete)
                           └── HoverHandler (tooltip info)
```

## Standalone Usage

For editors other than VS Code, start the language server manually:

```bash
dotnet run --project KF.Jex.LanguageServer/src/KF.Jex.LanguageServer.csproj
```

The server communicates over stdin/stdout using the LSP JSON-RPC protocol.

## See Also

- [11-Jex.md](11-Jex.md) — JEX library reference
- [11b-Jex-VSCode.md](11b-Jex-VSCode.md) — VS Code extension that bundles this server

---

# KoreForge.Json

| | |
|---|---|
| **Package** | `KoreForge.Json` |
| **Namespace** | `KoreForge.Json` |
| **Source** | `KoreForge.Json/src/KF.Json/` |
| **Tests** | `KoreForge.Json/tst/KF.Json.Tests/` |
| **Dependencies** | None |

## Problem

Two recurring JSON problems in message-processing systems:

1. **Escaped JSON.** JSON payloads frequently arrive with nested JSON encoded as escaped strings (e.g., a Kafka message body where the `payload` field is `"{\"orderId\":123}"`). Consumer code must detect these, unescape them, parse the inner JSON, and reintegrate it into the document tree. This is tedious, error-prone, and done repeatedly across services.

2. **Message routing.** High-throughput systems receive heterogeneous JSON messages on a single topic and need to route them by inspecting a root property (e.g., `eventType`). Parsing the full document just to read one field is wasteful. A zero-allocation UTF-8 scan is much cheaper.

## Solution

KoreForge.Json provides two focused utilities:

- **`JsonMaterializer`** — recursively expands escaped JSON strings into their parsed object form. Accepts an optional `MaxDepth` to prevent infinite recursion and optional `FieldHints` to limit which fields are expanded.
- **`RootPropertyClassifier`** — scans raw UTF-8 bytes for a root-level property and matches its value against a set of regex patterns. Returns a numeric route ID. Zero allocation on the hot path.

Both are also available as JEX bridge functions (`expandJson()` for use inside JEX scripts).

## Compromises

- `JsonMaterializer` must parse and re-serialize, so deeply nested escaped payloads incur proportional overhead.
- `RootPropertyClassifier` only inspects root-level properties — it cannot route based on nested fields.

## Installation

```bash
dotnet add package KoreForge.Json
```

## DI Registration

No DI registration required. Both classes are stateless and can be used directly.

## Configuration

### JsonMaterializer

```csharp
var options = new JsonMaterializerOptions
{
    MaxDepth = 10,                       // Maximum recursion depth (default: 10)
    FieldHints = ["payload", "body"]     // Only expand these fields (null = expand all)
};
```

### RootPropertyClassifier

Configured at construction time:

```csharp
var classifier = new RootPropertyClassifier(
    propertyNames: ["eventType", "source"],
    matches: new List<KeyValuePair<int, Regex>>
    {
        new(1, new Regex("^order\\.")),
        new(2, new Regex("^payment\\.")),
        new(0, new Regex(".*"))         // default route
    }
);
```

## API Reference

### `JsonMaterializer`

```csharp
public static class JsonMaterializer
{
    // Expand all escaped JSON strings in the input
    public static string Expand(string json);
    public static string Expand(string json, JsonMaterializerOptions options);
}
```

### `RootPropertyClassifier`

```csharp
public class RootPropertyClassifier
{
    public RootPropertyClassifier(string[] propertyNames, List<KeyValuePair<int, Regex>> matches);

    // Classify raw UTF-8 bytes — zero allocation on hot path
    public int Classify(ReadOnlySpan<byte> utf8Json);
}
```

### `ExpandJsonFunction` (JEX bridge)

In a JEX script:

```
{
  "expanded": "expandJson($in.payload, 5)"
}
```

## Examples

### Expanding escaped JSON

```csharp
string input = """{"payload":"{\"orderId\":123,\"items\":[{\"sku\":\"A1\"}]}"}""";
string expanded = JsonMaterializer.Expand(input);
// Result: {"payload":{"orderId":123,"items":[{"sku":"A1"}]}}
```

### Routing messages by type

```csharp
var classifier = new RootPropertyClassifier(
    propertyNames: ["eventType"],
    matches: new List<KeyValuePair<int, Regex>>
    {
        new(1, new Regex("^order")),
        new(2, new Regex("^payment")),
    }
);

byte[] message = Encoding.UTF8.GetBytes("""{"eventType":"order.created","data":{}}""");
int route = classifier.Classify(message);
// route == 1
```

---

# KoreForge.Metrics

| | |
|---|---|
| **Package** | `KoreForge.Metrics` |
| **Namespace** | `KoreForge.Metrics` |
| **Source** | `KoreForge.Metrics/src/KF.Metrics/` |
| **Tests** | `KoreForge.Metrics/tst/KF.Metrics.Tests/` |
| **Dependencies** | KoreForge.Time |

## Problem

Application-level metrics — operation counts, durations, error rates, queue depths — are essential for production visibility. But most metrics libraries (Prometheus client, OpenTelemetry) are designed for export to external systems. If the external system is unavailable, the metrics are lost. If the application needs to display its own metrics (e.g., a health dashboard), you have to query the external system back.

What is often needed instead is a bounded, in-memory metrics store that the application can query directly, with optional export to external systems as a secondary concern.

## Solution

KoreForge.Metrics provides `IOperationMonitor` — a bounded in-memory metrics engine. You create `OperationScope` instances to measure operations (timing, success/failure, tags). Snapshots are taken periodically and stored in a ring buffer. The application can query its own metrics at any time through `IMonitoringSnapshotProvider`.

Key properties: bounded memory (configurable max snapshots), lock-free hot path for recording, CPU sampling, and async event sinks for side-channel export.

## Compromises

- Metrics are in-memory and bounded. Old snapshots are evicted when the buffer is full. This is not a time-series database — it is a dashboard buffer.
- No built-in Prometheus or OpenTelemetry export. You can attach an event sink to forward snapshots to any external system, but it is not preconfigured.

## Installation

```bash
dotnet add package KoreForge.Metrics
```

## DI Registration

```csharp
builder.Services.AddKoreForgeMetrics(options =>
{
    options.MaxSnapshots = 100;           // Ring buffer size
    options.SnapshotIntervalSeconds = 10; // How often to snapshot
});
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `MaxSnapshots` | int | 100 | Maximum snapshots retained in ring buffer |
| `SnapshotIntervalSeconds` | int | 10 | Seconds between automatic snapshots |

## API Reference

### `IOperationMonitor`

```csharp
public interface IOperationMonitor
{
    OperationScope BeginOperation(string operationName, OperationTags? tags = null);
}
```

### `OperationScope`

```csharp
public class OperationScope : IDisposable
{
    public void Complete();       // Mark success — records duration
    public void Fail();           // Mark failure — records duration + error count
    public void Dispose();        // If neither Complete/Fail called, records as failure
}
```

### `OperationTags`

Key-value pairs attached to an operation for filtering/grouping.

### `IMonitoringSnapshotProvider`

```csharp
public interface IMonitoringSnapshotProvider
{
    IReadOnlyList<MonitoringSnapshot> GetSnapshots();
    MonitoringSnapshot? GetLatestSnapshot();
}
```

### `MonitoringSnapshot`

Contains: timestamp, operation counts, durations, error counts, CPU usage, queue depths.

## Examples

### Instrumenting an operation

```csharp
public class OrderService(IOperationMonitor monitor)
{
    public async Task ProcessOrderAsync(Order order)
    {
        using var scope = monitor.BeginOperation("process-order",
            new OperationTags { ["orderId"] = order.Id.ToString() });
        try
        {
            await DoWork(order);
            scope.Complete();
        }
        catch
        {
            scope.Fail();
            throw;
        }
    }
}
```

### Querying metrics

```csharp
public class DashboardService(IMonitoringSnapshotProvider snapshots)
{
    public int GetRecentErrorCount()
    {
        var latest = snapshots.GetLatestSnapshot();
        return latest?.TotalErrors ?? 0;
    }
}
```

## See Also

- [20a-Metrics-AspNet.md](20a-Metrics-AspNet.md) — HTTP endpoints for metrics exposure

---

# KoreForge.Metrics.AspNet

| | |
|---|---|
| **Package** | `KoreForge.Metrics.AspNet` |
| **Namespace** | `KoreForge.Metrics.AspNet` |
| **Source** | `KoreForge.Metrics.AspNet/src/KF.Metrics.AspNet/` |
| **Tests** | `KoreForge.Metrics.AspNet/tst/KF.Metrics.AspNet.Tests/` |
| **Dependencies** | KoreForge.Metrics |

## Problem

KoreForge.Metrics stores snapshots in memory, but there is no way to view them from outside the process without writing custom HTTP endpoints.

## Solution

KoreForge.Metrics.AspNet registers ASP.NET Core endpoints that expose the metrics snapshot buffer as JSON. Point a browser, curl, or a monitoring dashboard at the endpoint and see the application's live metrics.

## Compromises

- Adds an ASP.NET Core dependency. Not usable in non-web applications (use `IMonitoringSnapshotProvider` directly instead).
- The endpoint is unauthenticated by default. Secure it behind authorization middleware in production.

## Installation

```bash
dotnet add package KoreForge.Metrics.AspNet
```

## DI Registration

### Minimal API

```csharp
var app = builder.Build();
app.MapKoreForgeMetrics();    // Registers GET /metrics/snapshots
```

### MVC / Controllers

```csharp
builder.Services.AddControllers()
    .AddKoreForgeMetricsEndpoints();
```

## Configuration

No additional configuration. The endpoint path defaults to `/metrics/snapshots`.

## API Reference

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/metrics/snapshots` | Returns all retained snapshots as JSON array |
| GET | `/metrics/snapshots/latest` | Returns the most recent snapshot |

---

# KoreForge.Logging

| | |
|---|---|
| **Package** | `KoreForge.Logging` |
| **Namespace** | `KoreForge.Logging` |
| **Source** | `KoreForge.Logging/src/` (Runtime, Generator, Analyzers) |
| **Tests** | `KoreForge.Logging/tst/KF.Logging.Tests/` |
| **Dependencies** | KoreForge.Metrics, KoreForge.Time |

## Problem

Structured logging in large systems degrades into chaos. Teams invent their own event IDs, log message formats, and severity conventions. There is no discoverability — you cannot ask "what are all the log events this application emits?" without reading every line of source code. When event ID 1001 in Service A means "order received" and event ID 1001 in Service B means "cache miss," correlation across services becomes guesswork.

## Solution

KoreForge.Logging uses Roslyn source generation to produce log methods from an enum hierarchy. You define your log events once as nested enums + attributes. The source generator produces strongly-typed extension methods with deterministic event IDs derived from the hierarchy. The result: every log event has a unique, discoverable, type-safe entry point.

The assembly ships in three parts:
- `KF.Logging.Runtime.dll` — runtime types and base interfaces
- `KF.Logging.Generator.dll` (netstandard2.0) — Roslyn source generator that emits log methods at compile time
- `KF.Logging.Analyzers.dll` — Roslyn analyzers that enforce logging conventions

## Compromises

- The source generator adds compile-time dependency. If the generator has a bug, it manifests as a build error, not a runtime error.
- The enum-based hierarchy is rigid by design. You cannot add a new log event without modifying the enum and rebuilding. This is the point — it prevents ad-hoc `logger.LogInformation("something happened")` calls.

## Installation

```bash
dotnet add package KoreForge.Logging
```

## DI Registration

```csharp
builder.Services.AddLogging();
builder.Services.AddGeneratedLogging();
```

## Configuration

Logging levels follow the standard `Microsoft.Extensions.Logging` configuration in `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "KoreForge": "Debug"
    }
  }
}
```

## API Reference

### How It Works

1. Define an enum hierarchy with `[LogEvent]` attributes:

```csharp
public enum AppEvents
{
    [LogEvent(Level = LogLevel.Information, Message = "Order received: {OrderId}")]
    OrderReceived,

    [LogEvent(Level = LogLevel.Error, Message = "Payment failed: {OrderId}, Reason: {Reason}")]
    PaymentFailed
}
```

2. The source generator produces strongly-typed extension methods:

```csharp
// Auto-generated — do not edit
public static void OrderReceived(this ILogger logger, string orderId) { ... }
public static void PaymentFailed(this ILogger logger, string orderId, string reason) { ... }
```

3. Use in code:

```csharp
logger.OrderReceived(order.Id);
logger.PaymentFailed(order.Id, ex.Message);
```

### Event ID Assignment

Event IDs are deterministic, derived from the enum hierarchy position. Nested enums produce namespaced IDs (e.g., `Kafka.Consumer.BatchReceived` → event ID 3001001). This means:
- IDs never collide across namespaces
- IDs are stable across builds (they depend on hierarchy, not source order)
- You can search for an event ID and find the exact enum member

### Benefits

- **Discoverability:** List all log events by reading the enum definitions
- **Consistency:** Message templates are defined once, not scattered across code
- **Zero-drift:** The log call site and the message format cannot diverge — the generator produces both

## See Also

- [21a-Logging-Serilog.md](21a-Logging-Serilog.md) — Serilog sink integration

---

# KoreForge.Logging.Serilog

| | |
|---|---|
| **Package** | `KoreForge.Logging.Serilog` |
| **Namespace** | `KoreForge.Logging.Serilog` |
| **Source** | `KoreForge.Logging.Serilog/src/KF.Logging.Serilog/` |
| **Dependencies** | KoreForge.Logging, Serilog |

## Problem

Many production environments use Serilog with LogStash-format sinks for centralized log aggregation. The standard `Microsoft.Extensions.Logging` → Serilog bridge works, but KoreForge's generated log events need specific sink configuration to preserve the hierarchical event structure in LogStash-format output.

## Solution

KoreForge.Logging.Serilog provides preconfigured Serilog sink integration that preserves KoreForge log event metadata (event IDs, hierarchy) in the output format.

## Compromises

- Adds a direct dependency on Serilog. If you use a different logging backend, you do not need this package.

## Installation

```bash
dotnet add package KoreForge.Logging.Serilog
```

## DI Registration

```csharp
builder.Host.UseSerilog((context, config) =>
{
    config
        .ReadFrom.Configuration(context.Configuration)
        .AddKoreForgeLogStash(options =>
        {
            options.IncludeEventHierarchy = true;
        });
});
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `IncludeEventHierarchy` | bool | `true` | Include the full event hierarchy path in log output |

---

# KoreForge.Processing

| | |
|---|---|
| **Package** | `KoreForge.Processing` |
| **Namespace** | `KoreForge.Processing` |
| **Source** | `KoreForge.Processing/src/` |
| **Tests** | `KoreForge.Processing/tst/` |
| **Dependencies** | Microsoft.Extensions.DependencyInjection.Abstractions |

## Problem

Non-trivial applications need to chain operations together: validate → enrich → transform → persist. Without a formal structure, these chains end up as nested method calls, deeply indented `if` blocks, or ad-hoc "service" classes with names like `OrderProcessingOrchestrator`. The control flow is hidden inside imperative code, making it hard to test individual steps, reorder them, or add cross-cutting concerns like timing and error handling.

## Solution

KoreForge.Processing provides two composable patterns:

**Pipelines** for linear data transformation — each step takes an input type and produces a new output type. Steps are pure functions that can be tested in isolation.

**Flows** for state-machine orchestration — stages share a mutable context and can branch to different next stages based on outcomes.

Both patterns support DI-resolved steps/stages, cancellation, and pluggable observability.

## Compromises

- The pipeline generic signature `IPipelineStep<TIn, TOut>` can become verbose with many steps. This is intentional — the types document the data flow at the interface level.
- Flows use mutable context objects, which sacrifices the immutability of pipelines. This is the right trade-off for processes where stages need to share state.

## Installation

```bash
dotnet add package KoreForge.Processing
```

## DI Registration

Steps and stages are resolved from the DI container automatically when registered:

```csharp
builder.Services.AddTransient<ValidateOrderStep>();
builder.Services.AddTransient<EnrichOrderStep>();
builder.Services.AddTransient<PersistOrderStep>();
```

## Configuration

No configuration options. Pipeline and flow behavior is defined by the builder API.

## API Reference

### Building a Pipeline

```csharp
var pipeline = Pipeline
    .Start<RawOrder>()
    .AddStep<ValidateOrderStep>()     // RawOrder → ValidatedOrder
    .AddStep<EnrichOrderStep>()       // ValidatedOrder → EnrichedOrder
    .AddStep<PersistOrderStep>()      // EnrichedOrder → PersistedOrder
    .Build();

var result = await pipeline.ExecuteAsync(rawOrder, context, cancellationToken);
```

### Writing a Pipeline Step

```csharp
public class ValidateOrderStep : IPipelineStep<RawOrder, ValidatedOrder>
{
    public Task<ValidatedOrder> ExecuteAsync(
        RawOrder input,
        IPipelineContext context,
        CancellationToken cancellationToken)
    {
        // Validate and transform
        return Task.FromResult(new ValidatedOrder(input));
    }
}
```

### `IPipelineContext`

```csharp
public interface IPipelineContext
{
    T GetService<T>();                         // Resolve from DI
    IDictionary<string, object> Properties;    // Shared properties bag
    CancellationToken CancellationToken { get; }
}
```

### Building a Flow

```csharp
var flow = Flow
    .Create<CheckoutContext>("checkout")
    .AddStage<ValidateCartStage>()
    .AddStage<ProcessPaymentStage>()
    .AddStage<ConfirmOrderStage>()
    .Build();

var context = new CheckoutContext { Cart = cart };
await flow.ExecuteAsync(context, flowCtx, cancellationToken);
```

### Writing a Flow Stage

```csharp
public class ValidateCartStage : IFlowStage<CheckoutContext>
{
    public Task ExecuteAsync(
        CheckoutContext context,
        IFlowContext flowCtx,
        CancellationToken cancellationToken)
    {
        // Validate and mutate context
        context.IsValid = context.Cart.Items.Count > 0;
        return Task.CompletedTask;
    }
}
```

### Package Assemblies

| Assembly | Contains |
|----------|---------|
| `KF.Processing.Pipeline.dll` | Pipeline builder and execution |
| `KF.Processing.Pipeline.Abstractions.dll` | `IPipelineStep`, `IPipelineContext` |
| `KF.Processing.Flow.dll` | Flow builder and execution |
| `KF.Processing.Flow.Abstractions.dll` | `IFlowStage`, `IFlowContext` |
| `KF.Processing.Pipelines.dll` | Built-in compound types |

## Pipeline vs Flow — Decision Guide

| Question | Pipeline | Flow |
|----------|----------|------|
| Does each step produce a new type? | Yes | No |
| Is the work data transformation? | Yes | No |
| Do stages share mutable state? | No | Yes |
| Can stages branch based on outcomes? | No | Yes |
| Is it a business process with many actors? | No | Yes |

---

# KoreForge.AppLifecycle

| | |
|---|---|
| **Package** | `KoreForge.AppLifecycle` |
| **Namespace** | `KoreForge.AppLifecycle` |
| **Source** | `KoreForge.AppLifecycle/src/` |
| **Tests** | `KoreForge.AppLifecycle/tst/` |
| **Dependencies** | KoreForge.Processing |

## Problem

Every application has startup and shutdown work: run database migrations, warm caches, seed reference data, drain message queues, flush metrics. This work is typically scattered across `Program.cs`, `IHostedService` implementations, and ad-hoc startup classes. There is no unified sequencing, no error handling policy, and no visibility into what ran, how long it took, or whether it succeeded.

Background scheduled tasks have the same problem — they are implemented as `BackgroundService` subclasses with `while (true) { ... await Task.Delay(...) }` loops, each with its own error handling and interval logic.

## Solution

KoreForge.AppLifecycle provides a structured manager for startup flows, shutdown flows, and scheduled flows. Each flow is a `KoreForge.Processing` flow with defined stages. The lifecycle manager executes startup flows sequentially before the application accepts traffic, executes shutdown flows on stop signal, and runs scheduled flows concurrently in the background.

## Compromises

- Startup flows run sequentially. If you need parallel startup (e.g., warming two caches simultaneously), you must do the parallelism inside a single flow.
- Scheduled flows use `TimeSpan` intervals, not cron expressions. For cron-style scheduling, implement `IScheduleTrigger`.

## Installation

```bash
dotnet add package KoreForge.AppLifecycle
```

## DI Registration

```csharp
builder.Services.AddApplicationLifecycleManager(options =>
{
    // Startup flows — run sequentially before app accepts traffic
    options.AddStartupFlow<DatabaseMigrationFlow>();
    options.AddStartupFlow<SeedReferenceDataFlow>();
    options.AddStartupFlow<WarmCacheFlow>();

    // Shutdown flows — run sequentially on stop signal
    options.AddShutdownFlow<DrainMessagesFlow>();
    options.AddShutdownFlow<FlushMetricsFlow>();

    // Scheduled flows — run concurrently in background
    options.AddScheduledFlow<HeartbeatFlow>(schedule =>
    {
        schedule.Interval = TimeSpan.FromSeconds(30);
    });
    options.AddScheduledFlow<CacheRefreshFlow>(schedule =>
    {
        schedule.Interval = TimeSpan.FromMinutes(5);
        schedule.RunOnStartup = true;
    });
});
```

This automatically registers:
- `ApplicationLifecycleHostedService` — manages startup/shutdown
- `ScheduledTasksHostedService` — manages scheduled flows

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `FailFastOnStartupFailure` | bool | `true` | Abort application start if any startup flow fails |
| `FailFastOnShutdownFailure` | bool | `false` | Throw on shutdown flow failure |
| `UnmappedOutcomePolicy` | enum | `Throw` | What to do when a flow produces an unexpected outcome |

### Schedule Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Interval` | TimeSpan | — | Time between runs |
| `RunOnStartup` | bool | `false` | Execute immediately at startup in addition to schedule |
| `AbortOnException` | bool | `false` | Stop the schedule loop on unhandled exception |

## API Reference

### Defining a Flow

```csharp
public class DatabaseMigrationFlow : ILifecycleFlow
{
    public Task ExecuteAsync(CancellationToken cancellationToken)
    {
        // Run migrations
        return Task.CompletedTask;
    }
}
```

### Lifecycle Events

Implement `IApplicationLifecycleEvents` to observe lifecycle transitions:

| Event | When |
|-------|------|
| `BeforeStartupFlows` | Before any startup flow runs |
| `StartupStepExecuting` | Before each startup flow |
| `StartupStepExecuted` | After each startup flow (with duration) |
| `AfterStartupFlows` | After all startup flows complete |
| `BeforeShutdownFlows` | Before shutdown flows begin |
| `ShutdownStepExecuting` | Before each shutdown flow |
| `ShutdownStepExecuted` | After each shutdown flow |
| `AfterShutdownFlows` | After all shutdown flows complete |

### Custom Schedule Triggers

For cron-like scheduling, implement `IScheduleTrigger`:

```csharp
public class BusinessHoursTrigger : IScheduleTrigger
{
    public Task<TimeSpan> GetNextDelayAsync(CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        if (now.Hour >= 9 && now.Hour < 17)
            return Task.FromResult(TimeSpan.FromMinutes(5));
        else
            return Task.FromResult(TimeSpan.FromHours(1));
    }
}
```

### Error Handling

- **Startup:** Any exception throws `ApplicationLifecycleException` (with `FlowName`, `Phase`, `InnerException`). Application startup is aborted.
- **Shutdown:** Exceptions are logged and reported to metrics. Next shutdown flow still runs.
- **Scheduled:** Exceptions are logged and reported. Schedule continues unless `AbortOnException = true`.

## See Also

- `KoreForge.AppLifecycle/doc/UsageGuide.md` — Extended usage patterns
- `KoreForge.AppLifecycle/doc/Specification.md` — Full specification

---

# KoreForge.Kafka

| | |
|---|---|
| **Package** | `KF.Kafka` (meta), `KF.Kafka.Consumer`, `KF.Kafka.Producer`, `KF.Kafka.AdminClient`, `KF.Kafka.Configuration`, `KF.Kafka.Configuration.AspNetCore`, `KF.Kafka.Core` |
| **Namespace** | `KoreForge.Kafka.*` |
| **Source** | `KoreForge.Kafka/src/` |
| **Tests** | `KoreForge.Kafka/tst/` |
| **Dependencies** | Confluent.Kafka, KoreForge.Metrics, KoreForge.Logging |

## Problem

Kafka client code in .NET is low-level: you must manage consumer loops, deserialization, offset commits, error handling, backpressure, retries, and graceful shutdown yourself. Each team reinvents the same resilient wrapper, and the resulting code is tightly coupled to Confluent.Kafka primitives.

Producers face similar problems: buffering, delivery reports, backlog management, and backpressure are all left as exercises for the reader.

Monitoring consumer lag and topic health requires additional tooling that doesn't ship with the client library.

## Solution

KoreForge.Kafka provides a production-grade Kafka stack built on Confluent.Kafka:

- **Consumer:** Hosted service with automatic restart, pipeline integration, batch processing, backpressure, and structured logging.
- **Producer:** Buffered producer with delivery tracking, backpressure, backlog management, and metrics emission.
- **Admin Client:** Read-only surface for topic metadata, consumer-lag queries, and offsets-for-timestamp.
- **Configuration:** Profile-based configuration model with validation and generated factories.

## Compromises

- Requires Confluent.Kafka — not an abstraction over arbitrary message brokers.
- Consumer uses a single-threaded partition model per consumer group. High-throughput scenarios should deploy multiple consumer instances.
- The meta-package `KF.Kafka` pulls in all sub-packages. Use individual packages for leaner dependency trees.

## Installation

```bash
# Everything
dotnet add package KF.Kafka

# Or pick what you need
dotnet add package KF.Kafka.Consumer
dotnet add package KF.Kafka.Producer
dotnet add package KF.Kafka.AdminClient
```

## Configuration

Define profiles in `appsettings.json`:

```json
{
  "Kafka": {
    "Profiles": {
      "Default": {
        "BootstrapServers": "localhost:29092",
        "SecurityProtocol": "Plaintext"
      }
    }
  }
}
```

## DI Registration

```csharp
// 1. Register configuration profiles
services.AddKafkaConfiguration(configuration.GetSection("Kafka"));

// 2. Register a producer
services.AddKafkaProducer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topic = "my-events";
});

// 3. Register a consumer
services.AddKafkaConsumer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topics = new[] { "my-events" };
    options.GroupId = "my-service";
});

// 4. Register admin client (optional)
services.AddKafkaAdminClient(configuration.GetSection("Kafka:Admin"));
```

## API Reference

### Producer

Inject `IKafkaProducer<TKey, TValue>`:

```csharp
public class OrderPublisher(IKafkaProducer<string, OrderCreated> producer)
{
    public Task PublishAsync(OrderCreated evt, CancellationToken ct)
        => producer.EnqueueAsync(evt.OrderId, evt, ct);
}
```

### Consumer

Implement `IKafkaMessageHandler<TKey, TValue>`:

```csharp
public class OrderHandler : IKafkaMessageHandler<string, OrderCreated>
{
    public Task HandleAsync(ConsumeResult<string, OrderCreated> message, CancellationToken ct)
    {
        // Process the message
        return Task.CompletedTask;
    }
}
```

### Admin Client

Inject `IKafkaAdminClient`:

```csharp
public class LagMonitor(IKafkaAdminClient admin)
{
    public async Task<ConsumerGroupLagSummary> GetLagAsync()
        => await admin.GetConsumerGroupLagSummaryAsync(
            "my-service",
            new ConsumerGroupLagQuery { TopicFilter = new[] { "my-events" } });
}
```

## Sub-Packages

| Package | Description |
|---|---|
| `KF.Kafka` | Meta-package — installs all components below |
| `KF.Kafka.AdminClient` | Read-only admin: topic metadata, consumer-lag, offsets-for-timestamp |
| `KF.Kafka.Configuration` | Configuration model, profiles, validation, generated factories |
| `KF.Kafka.Configuration.AspNetCore` | ASP.NET Core integration for configuration |
| `KF.Kafka.Consumer` | Resilient consumer host with backpressure, routing, pipeline, restart |
| `KF.Kafka.Core` | Shared runtime records, alert engine, diagnostics |
| `KF.Kafka.Producer` | Resilient producer with buffering, backpressure, backlog, metrics |

## Docker Dev Environment

A local development environment ships in `samples/docker/`:

| Component | Port | Purpose |
|---|---|---|
| Redpanda | `29092` | Kafka-compatible broker |
| Azure SQL Edge | `14333` | SQL Server for settings/state |

```powershell
.\samples\docker\up.ps1     # Start and configure infrastructure
.\samples\docker\down.ps1   # Stop
```

## See Also

- `KoreForge.Kafka/doc/UsageGuide.md` — Extended usage examples
- `KoreForge.Kafka/doc/AdminClient.md` — Admin client reference
- `KoreForge.Kafka/samples/docker/` — Docker Compose files

---

# KoreForge.Web

| | |
|---|---|
| **Package** | `KoreForge.Web.RestApi.Abstractions`, `KoreForge.Web.RestApi.Observability`, `KoreForge.Web.RestApi.Persistence`, `KoreForge.Web.Authorization` |
| **Namespace** | `KoreForge.Web.*` |
| **Source** | `KoreForge.Web/src/` |
| **Tests** | `KoreForge.Web/tst/` |
| **Dependencies** | ASP.NET Core, KoreForge.Metrics, KoreForge.Logging |

## Problem

Building production REST APIs in ASP.NET Core requires repeated scaffolding: response envelopes, error handling, ProblemDetails formatting, audit logging, authorization middleware, health checks, observability wiring, and HTTP client configuration. Each team solves these differently, producing inconsistent APIs with varying error formats and security postures.

Integrating with external APIs introduces even more boilerplate: Refit client generation, retry policies, circuit breakers, request/response logging, and correlation ID propagation.

## Solution

KoreForge.Web provides a multi-layer REST API framework that separates concerns into discrete, testable packages:

- **Abstractions** — Shared contracts, options, and extension points common to all layers.
- **Observability** — Structured logging, metrics, and correlation ID propagation for HTTP traffic.
- **Persistence** — API call audit persistence using `ApiCallAudit` records (ApiName, Operation, Direction, StatusCode, CorrelationId, RequestPayload, ResponsePayload).
- **Authorization** — Role semantics engine with policy-based authorization and tenant isolation.
- **Host** — Internal Web host for multi-API aggregation behind a single entry point.

## Compromises

- The layer model (External → Domain → Internal → Client) is opinionated. Simpler APIs may find the four-layer structure excessive.
- OpenAPI-first external integration requires an `openapi.json` per provider. If no spec exists, you must write one.
- Roslyn analyzers enforce layer boundaries at compile time. This catches violations early but adds initial learning curve.

## Architecture

The framework follows a four-layer pattern for each API integration:

```
┌────────────────────────────────────────────────────────────────┐
│  Client SDK         →  I<Api>Client (consumer-facing)          │
│  Internal Endpoints →  /api/<name>/...   (minimal APIs)        │
│  Domain Layer       →  Use cases, orchestration, audit          │
│  External Layer     →  Refit proxy, DTO mapping, hooks          │
└────────────────────────────────────────────────────────────────┘
```

## DI Registration

Each layer follows a consistent registration pattern:

```csharp
// External: transport + hooks
services.Add<ApiName>External(configuration);

// Domain: orchestration + audit
services.Add<ApiName>Domain();

// Internal: HTTP endpoints
app.Map<ApiName>Endpoints();

// Client SDK: consumer-side
services.Add<ApiName>Client(configuration);
```

## Key Types

### ApiCallAudit

Captures every cross-boundary HTTP call:

```csharp
public record ApiCallAudit
{
    public string ApiName { get; init; }
    public string Operation { get; init; }
    public string Direction { get; init; }     // Inbound | Outbound
    public int StatusCode { get; init; }
    public string CorrelationId { get; init; }
    public string? RequestPayload { get; init; }
    public string? ResponsePayload { get; init; }
}
```

### ApiCallHooksDelegatingHandler

Automatically captures raw request/response JSON for audit and debugging. Registered transparently by the External layer.

### ProblemDetails

All errors return RFC 7807 ProblemDetails with a correlation ID:

```json
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Not Found",
  "status": 404,
  "detail": "Order 12345 not found",
  "instance": "/api/orders/12345",
  "correlationId": "abc-123"
}
```

### Authorization & Row-Level Filtering

```csharp
// Register row-level filter for multi-tenant isolation
services.AddScoped<IRowLevelFilterProvider<Order>, TenantOrderFilter>();
```

## Sub-Packages

| Package | Description |
|---|---|
| `KF.RestApi.Common.Abstractions` | Shared contracts, options |
| `KF.RestApi.Common.Analyzers` | Roslyn rules enforcing layer separation |
| `KF.RestApi.Common.Observability` | Observability helpers |
| `KF.RestApi.Common.Persistence` | Audit persistence |
| `KF.RestApi.Host.Internal` | Internal API host |
| `KF.Web.Authorization` | Role semantics & authorization |
| `KF.Web.HealthChecks` | Health check endpoints |

## See Also

- `KoreForge.Web/doc/3. Specification.md` — Full technical specification
- `KoreForge.Web/doc/versioning-guide.md` — API versioning guide

---

# KoreForge.Settings

| | |
|---|---|
| **Package** | `KoreForge.Settings` (meta), `KF.Settings`, `KF.Settings.Abstractions`, `KF.Settings.Core`, `KF.Settings.Data`, `KF.Settings.Encryption`, `KF.Settings.Metrics`, `KoreForge.Settings.Cli` |
| **Namespace** | `KoreForge.Settings.*` |
| **Source** | `KoreForge.Settings/src/` |
| **Tests** | `KoreForge.Settings/tst/` |
| **Dependencies** | EF Core (SQL Server), Microsoft.Extensions.Configuration |

## Problem

`appsettings.json` is baked into the deployment. Changing a setting means redeploying or manually editing files on a server. There is no audit trail, no rollback capability, and no way to change configuration at runtime across multiple instances of the same application.

Environment variables help but are difficult to manage at scale, offer no history, and cannot be queried or exported.

## Solution

KoreForge.Settings stores configuration in SQL Server with a .NET `IConfigurationProvider` that reloads automatically on a polling interval. Settings are scoped per application (and optionally per instance), support encryption for sensitive values, maintain full history with rollback, and expose health metrics. A CLI tool provides command-line management.

The configuration source is transparent to application code — `IConfiguration`, `IOptions<T>`, and `IOptionsMonitor<T>` all work as expected with hot-reload support.

## Compromises

- Requires SQL Server for storage. No pluggable backend (by design — one database, one source of truth).
- Polling-based reload, not push-based. Minimum interval is 30 seconds. Changes are not instant.
- Encryption is opt-in via `IEncryptionProvider`. The default implementation is no-op — you must provide your own encryption strategy for production secrets.

## Installation

```bash
dotnet add package KoreForge.Settings

# CLI tool (global)
dotnet tool install -g KoreForge.Settings.Cli
```

## DI Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

// 1. Add KF Settings as a configuration source
builder.Configuration.AddKFSettings(opts =>
{
    opts.ApplicationId = "my-app";
    opts.PollingInterval = TimeSpan.FromSeconds(30);
    opts.EnableMetrics = true;
});

// 2. Register services
builder.Services.AddKFSettingsServices(builder.Configuration);
```

## Connection String Resolution

The connection string is resolved in priority order:

1. `KFSettingsOptions.ConnectionString` — set directly in code
2. `ConnectionStrings:KFSettings` — from `appsettings.json`
3. `KF:Settings:ConnectionString` — from configuration
4. `KF_SETTINGS_CONNECTIONSTRING` — environment variable

## Configuration Options

| Property | Default | Description |
|----------|---------|-------------|
| `ConnectionString` | _(resolved)_ | SQL Server connection string |
| `ApplicationId` | `null` | Scope filter for multi-app isolation |
| `InstanceId` | `null` | Optional instance-level scope |
| `PollingInterval` | `60s` | Background reload frequency (min 30s) |
| `BinaryEncoding` | `Base64Url` | Encoding for binary settings |
| `FailFastOnStartup` | `true` | Throw on startup validation failure |
| `EnableDecryption` | `false` | Enable value decryption (requires `IEncryptionProvider`) |
| `EnableMetrics` | `true` | In-memory metrics collection |
| `EnableDetailedLogging` | `false` | Verbose reload traces |

## API Reference

### ISettingsService

```csharp
public interface ISettingsService
{
    Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct);
    Task<SettingRow?> GetAsync(long id, CancellationToken ct);
    Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct);
    Task DeleteAsync(long id, string changedBy, byte[] expectedRowVersion, CancellationToken ct);
}
```

### IHistoryService

```csharp
public interface IHistoryService
{
    Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct);
    Task RollbackAsync(string key, int versionIndex, string changedBy, CancellationToken ct);
}
```

### Hot Reload

The `SettingsReloadBackgroundService` polls SQL Server at the configured interval. Change detection uses row count + max row version + key checksum. Updates are atomic — the configuration snapshot is rebuilt entirely before being swapped in.

Health is exposed via `IHealthReporter`:

```csharp
app.MapGet("/health/settings", (IHealthReporter health) =>
    new { health.LastSuccessfulReloadUtc, health.ConsecutiveFailures, health.LastRowCount });
```

## CLI Tool — `kf-settings`

```bash
kf-settings list     --application my-app --connection "Server=...;Database=...;"
kf-settings get      --application my-app --key "Feature:Enabled"
kf-settings set      --application my-app --key "Feature:Enabled" --value "true"
kf-settings delete   --application my-app --key "Feature:Enabled"
kf-settings history  --application my-app --key "Feature:Enabled"
kf-settings rollback --application my-app --key "Feature:Enabled" --version 2
kf-settings export   --application my-app > settings.json
kf-settings import   --application my-app < settings.json
```

## Sub-Packages

| Package | Description |
|---|---|
| `KF.Settings` | Configuration provider, hot-reload background service |
| `KF.Settings.Abstractions` | Models, interfaces, options |
| `KF.Settings.Core` | `SettingsService`, `HistoryService`, binary accessor |
| `KF.Settings.Data` | EF Core `KFSettingsDbContext` |
| `KF.Settings.Encryption` | `IEncryptionProvider` contract + `NoOpEncryptionProvider` |
| `KF.Settings.Metrics` | In-memory metrics recorder for reload operations |
| `KF.Settings.Cli` | CLI tool |

## See Also

- `KoreForge.Settings/README.md` — Full README with additional examples

---

# KoreForge.OData

| | |
|---|---|
| **Package** | `KoreForge.OData`, `KoreForge.OData.Generators` |
| **Namespace** | `KoreForge.OData`, `KoreForge.OData.Generators` |
| **Source** | `KoreForge.OData/src/` |
| **Tests** | `KoreForge.OData/tst/` (unit: 21 tests, integration: 13 tests) |
| **Dependencies** | Microsoft.AspNetCore.OData, EF Core, Roslyn (generator) |

## Problem

Exposing an EF Core `DbContext` as an OData API requires writing a controller per entity, registering each entity in the EDM model, wiring up authorization per operation, and maintaining all of this as the database schema evolves. The boilerplate is proportional to the number of entities and is identical in structure — only the types change.

## Solution

KoreForge.OData provides a Roslyn source generator that inspects your `DbContext` at compile time and emits:

- One OData controller per DbSet, inheriting `KoreForgeODataController<TContext, TEntity, TKey>`
- An EDM configurator implementing `IEdmModelConfigurator`
- Schema-aware route prefixes: `/odata/{ContextPrefix}/{EntitySet}`

Security is declarative via attributes on entity classes. Row-level filtering is pluggable via DI.

## Compromises

- Source generators require `netstandard2.0` for the generator assembly. The runtime library targets `net10.0`.
- Only single-key entities are supported. Composite keys require manual controller implementation.
- The generator reads `DbSet<T>` properties — entities not exposed as DbSets are not generated.

## Installation

```xml
<PackageReference Include="KoreForge.OData" />
<PackageReference Include="KoreForge.OData.Generators"
                  OutputItemType="Analyzer"
                  ReferenceOutputAssembly="false" />
```

## DI Registration

```csharp
// Register the generated EDM configurator
builder.Services.AddEdmModelConfigurator<SalesEdmConfigurator>();

// Add controllers with OData support
builder.Services.AddControllers().AddKoreForgeOData();
```

## Usage

### 1. Annotate Entities

```csharp
[ODataAuthorize(ReadPolicy = "CanReadOrders", CreatePolicy = "CanCreateOrders")]
public class Order
{
    [Key]
    public int OrderId { get; set; }
    public string Description { get; set; } = "";

    [ODataPropertyRestriction(DenyPatch = true, DenyPut = true)]
    public string CreatedBy { get; set; } = "system";
}

[ODataIgnore]   // Excluded from OData generation
public class AuditLog { /* ... */ }
```

### 2. Build

The source generator emits controllers and EDM configurators. No code to write.

### 3. Routes

Generated routes follow the pattern:

```
/odata/{ContextPrefix}/{EntitySet}
```

For a `SalesDbContext` with a `DbSet<Order>`, the route is `/odata/Sales/Orders`.

## Attributes

| Attribute | Target | Purpose |
|-----------|--------|---------|
| `[ODataAuthorize]` | Entity class | Per-operation policies: `ReadPolicy`, `CreatePolicy`, `UpdatePolicy`, `DeletePolicy` |
| `[ODataIgnore]` | Entity class | Exclude entity from OData generation |
| `[ODataPropertyRestriction]` | Property | `DenyPatch`, `DenyPut`, `DenyRead`, `DenySerialization` |

## Security Layers

### Entity-Level Authorization

`[ODataAuthorize]` maps CRUD operations to ASP.NET Core authorization policies:

```csharp
[ODataAuthorize(
    ReadPolicy = "Reader",
    CreatePolicy = "Writer",
    UpdatePolicy = "Writer",
    DeletePolicy = "Admin")]
public class Product { ... }
```

### Property-Level Restrictions

```csharp
[ODataPropertyRestriction(DenyPatch = true, DenySerialization = true)]
public string InternalNotes { get; set; }
```

### Row-Level Filtering

Implement `IRowLevelFilterProvider<TEntity>` and register in DI:

```csharp
public class TenantOrderFilter : IRowLevelFilterProvider<Order>
{
    public IQueryable<Order> ApplyFilter(IQueryable<Order> query)
        => query.Where(o => o.TenantId == _currentTenant.Id);
}

builder.Services.AddScoped<IRowLevelFilterProvider<Order>, TenantOrderFilter>();
```

## OData Query Support

| Option | Example |
|--------|---------|
| `$filter` | `/odata/Sales/Orders?$filter=Total gt 100` |
| `$select` | `/odata/Sales/Orders?$select=OrderId,Total` |
| `$orderby` | `/odata/Sales/Orders?$orderby=Total desc` |
| `$top` / `$skip` | `/odata/Sales/Orders?$top=10&$skip=20` |
| `$count` | `/odata/Sales/Orders?$count=true` |
| `$expand` | `/odata/Sales/Orders?$expand=Items` |

## See Also

- `KoreForge.OData/doc/UsageGuide.md` — Extended usage guide
- `KoreForge.OData/doc/SecurityGuide.md` — Security configuration reference

---

# KoreForge.Templates

| | |
|---|---|
| **Package** | `KoreForge.Templates` |
| **Source** | `KoreForge.Templates/` |
| **Dependencies** | .NET SDK template engine |

## Problem

Starting a new KoreForge project requires recreating the same solution structure, wiring up DI, adding standard scripts, configuring build properties, and importing the correct NuGet packages. This setup takes time and is error-prone — teams forget scripts, misconfigure settings, or skip observability wiring.

## Solution

KoreForge.Templates is a NuGet template pack that provides `dotnet new` scaffolding. Each template produces a complete, buildable solution with all KoreForge conventions pre-applied: bin scripts, Directory.Build.props, Central Package Management, DI registration, structured logging, health checks, and observability.

## Installation

```powershell
dotnet new install KoreForge.Templates
```

## Available Templates

| Short Name | Type | Description |
|---|---|---|
| `kf-kafka-processor` | Solution | Kafka consumer with Vue 3 dashboard, SignalR metrics, SQL live-reload settings, structured logging, health checks |
| `kf-data` | Solution | EF Core data library with database-first scaffolding, partial DbContext, options, and DI registration |
| `kf-odata` | Solution | OData controller library with Roslyn source-generated CRUD controllers from a DbContext |

---

## kf-kafka-processor

Creates a full Kafka consumer application with dashboard.

```powershell
dotnet new kf-kafka-processor -n MyApp --KafkaTopic orders --DatabaseName OrderDb
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Application name (replaces `EventProcessor` throughout) |
| `--KafkaTopic` | `transactions` | Kafka topic to consume |
| `--DatabaseName` | `FraudEngine` | SQL Server database name |

### What You Get

- ASP.NET Core host with Kafka consumer pipeline
- Vue 3 SPA dashboard with live SignalR metrics
- SQL Server-backed live-reload settings (KoreForge.Settings)
- Structured logging with source-generated event IDs
- Docker Compose for local dev (Redpanda + SQL Edge)
- Health check endpoints
- Standard bin scripts

---

## kf-data

Creates an EF Core data library using database-first scaffolding.

```powershell
dotnet new kf-data -n MyCompany.Data.Staff --DatabaseShort Staff
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Project name and namespace |
| `--DatabaseShort` | `Alerts` | Short name for DbContext, options, methods (e.g. `Staff` → `StaffDbContext`) |

### Post-Scaffold Steps

1. Edit `config/scaffold-config.json` with your connection string and schemas
2. Run `./scr/scaffold-db.ps1` to generate entity classes from the database

---

## kf-odata

Creates an OData controller library with source-generated CRUD endpoints.

```powershell
dotnet new kf-odata -n MyCompany.OData.Staff --DatabaseShort Staff --DataNamespace MyCompany.Data.Staff
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Project name and namespace |
| `--DatabaseShort` | `Alerts` | Short name matching Data library (e.g. `Staff` → `StaffDbContext`) |
| `--DataNamespace` | `KF.Data.Alerts` | Full namespace of the Data library where the DbContext lives |

### Post-Scaffold Steps

1. Add a `ProjectReference` to your Data library in the `.csproj`
2. Build to trigger source generation
3. Run `./scr/scaffold-odata.ps1` if additional scaffolding is needed

---

## Template Sources

| Template | Source Location |
|---|---|
| `kf-kafka-processor` | `apps/EventProcessor/` — the live app IS the template (golden master) |
| `kf-data` | `templates/kf-data/` — standalone template archetype |
| `kf-odata` | `templates/kf-odata/` — standalone template archetype |

## Local Development

```powershell
# Install templates from source
./scr/install-local.ps1

# Test 
dotnet new kf-data -n TestData --DatabaseShort Test -o /tmp/TestData

# Uninstall
./scr/uninstall-local.ps1

# Pack for release
./scr/build-pack.ps1    # → artifacts/KoreForge.Templates.<version>.nupkg
```

## See Also

- `KoreForge.Templates/README.md` — Full README
- `KoreForge.Templates/bin/` — Build and install scripts

---

# Tools and Scripts Reference

Every KoreForge repository ships with a standard set of automation scripts in its `scr/` directory. These scripts are designed to be run from any working directory — they resolve paths relative to the repository root automatically.

The workspace also contains top-level scripts for cross-repository operations.

---

## Per-Repository Scripts

These scripts exist in every library repository's `scr/` folder. Replace `{Solution}` with the repo name (e.g. `KoreForge.Kafka.slnx`).

### build-clean.ps1

**NAME**
    build-clean — Remove all build artifacts

**SYNOPSIS**
```powershell
.\scr\build-clean.ps1
```

**DESCRIPTION**
    Runs `dotnet clean` on the solution and removes the `out/` directory.

---

### build-rebuild.ps1

**NAME**
    build-rebuild — Force-rebuild the solution

**SYNOPSIS**
```powershell
.\scr\build-rebuild.ps1 [-Configuration <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Release` | Build configuration |

**DESCRIPTION**
    Runs `dotnet build --force` on the solution.

---

### build-test.ps1

**NAME**
    build-test — Build and run all tests

**SYNOPSIS**
```powershell
.\scr\build-test.ps1 [-Configuration <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Debug` | Build configuration |

**DESCRIPTION**
    Builds the solution, runs all tests, and writes an HTML test report under `artifacts/repos/<repo>/test-results`.

---

### build-test-codecoverage.ps1

**NAME**
    build-test-codecoverage — Build, test, and generate code coverage report

**SYNOPSIS**
```powershell
.\scr\build-test-codecoverage.ps1 [-Configuration <String>] [-Open]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Debug` | Build configuration |
| `-Open` | — | Open the HTML report in the default browser |

**DESCRIPTION**
    Builds the solution, runs tests with `XPlat Code Coverage` collection using `coverlet.runsettings`, then generates an HTML coverage report under `artifacts/repos/<repo>/coverage`.

---

### build-pack.ps1

**NAME**
    build-pack — Pack NuGet packages

**SYNOPSIS**
```powershell
.\scr\build-pack.ps1 [-Configuration <String>]
```

**DESCRIPTION**
    Runs `dotnet pack` on the solution. Output goes to the `artifacts/` directory. Not all repos include this script — some rely on CI/CD for packing.

---

### git-push.ps1

**NAME**
    git-push — Stage, commit, and push all changes

**SYNOPSIS**
```powershell
.\scr\git-push.ps1 -Message <String>
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Message` | Yes | Commit message |

**DESCRIPTION**
    Runs `git add -A`, `git commit -m`, and `git push` from the repository root.

---

### git-push-nuget.ps1

**NAME**
    git-push-nuget — Tag and push a release version

**SYNOPSIS**
```powershell
.\scr\git-push-nuget.ps1 -Version <String> [-Note <String>] [-TagOnly] [-Force]
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Version` | Yes | Semantic version (e.g. `0.0.6-alpha`) |
| `-Note` | No | Optional release note / commit message |
| `-TagOnly` | No | Skip committing — only create and push the tag |
| `-Force` | No | Re-create the tag if it already exists |

**DESCRIPTION**
    Creates a git tag in the format `{Prefix}/v{Version}` (e.g. `Kafka/v0.0.6-alpha`), optionally committing and pushing changes first. The tag triggers the GitHub Actions Trusted Publishing workflow.

---

### git-create-repo.ps1

**NAME**
    git-create-repo — Initialize and create a GitHub repository

**SYNOPSIS**
```powershell
.\scr\git-create-repo.ps1
```

**DESCRIPTION**
    Initializes the directory as a git repo (if needed), creates a public GitHub repository under `koreforger/{RepoName}`, and pushes the initial commit. Requires the GitHub CLI (`gh`).

---

### github-set-nuget-secret.ps1

**NAME**
    github-set-nuget-secret — Set the NUGET_API_KEY secret on the GitHub repository

**SYNOPSIS**
```powershell
.\bin\github-set-nuget-secret.ps1 [-ApiKey <String>]
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-ApiKey` | No | NuGet API key. If omitted, prompts interactively (masked input) |

**DESCRIPTION**
    Sets the `NUGET_API_KEY` repository secret via `gh secret set`. Used by the Trusted Publishing workflow.

---

## Workspace-Level Scripts

Located in the top-level `scr/` directory.

### pack-all.ps1

**NAME**
    pack-all — Pack all KoreForge NuGet packages

**SYNOPSIS**
```powershell
.\scr\pack-all.ps1 -Version <String>
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Version` | Yes | Version to stamp on all packages (e.g. `0.0.6-alpha`) |

**DESCRIPTION**
    Iterates all library repositories in dependency order (leaves first), runs `dotnet pack` with the specified version override, then packs template repos separately. Produces `.nupkg` files in each repo's `artifacts/` directory.

**Dependency Order:**
KoreForge.Time → KoreForge.Json → KoreForge.Data → KoreForge.OData → KoreForge.Logging → KoreForge.Logging.Serilog → KoreForge.Jex → KoreForge.AppLifecycle → KoreForge.Metrics → KoreForge.Metrics.AspNet → KoreForge.Processing → KoreForge.Settings → KoreForge.Web → KoreForge.Kafka → KoreForge.Templates

---

### create-all-repos.ps1

**NAME**
    create-all-repos — Create GitHub repositories for all projects

**SYNOPSIS**
```powershell
.\scr\create-all-repos.ps1
```

**DESCRIPTION**
    Iterates all library directories, runs each repo's `git-create-repo.ps1` to create the corresponding GitHub repository under `koreforger/`.

---

### zip-workspace.ps1

**NAME**
    zip-workspace — Archive the workspace for backup or sharing

**SYNOPSIS**
```powershell
.\scr\zip-workspace.ps1
```

**DESCRIPTION**
    Creates a zip archive of the entire KoreForge workspace, excluding build artifacts and generated files.

---

### Export-documentation.ps1

**NAME**
    Export-documentation — Generate combined documentation file

**SYNOPSIS**
```powershell
.\KoreForge.Main\scr\Export-documentation.ps1 [-OutputFile <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-OutputFile` | `KoreForge-Documentation.md` | Output file path |

**DESCRIPTION**
    Concatenates all markdown files from `doc/Introduction/` (sorted by filename) then `doc/Api/` (alphabetical) into a single combined documentation file. Re-running always picks up newly added docs.

---

## Docker Scripts (Kafka)

Located in `KoreForge.Kafka/samples/docker/`.

### up.ps1

Starts the local Kafka development environment (Redpanda on `localhost:29092`, Azure SQL Edge on `localhost:14333`), waits for services to be healthy, and runs configuration scripts.

### down.ps1

Stops and removes all Docker containers for the local dev environment.

---

## Template Scripts

Located in `KoreForge.Templates/bin/`.

### install-local.ps1

Installs all templates from source directories for local development testing.

### uninstall-local.ps1

Removes locally-installed template packages.

### pack.ps1

Packs the templates into `artifacts/KoreForge.Templates.<version>.nupkg`.

---

## NuGet Integration Test Scripts

Located in `KF.Nuget.Integration.Tests/scr/`.

### Build-Integration.ps1

Builds the integration test project against published NuGet packages (not local source).

### Clean-Integration.ps1

Cleans integration test build artifacts and NuGet caches.

### Install-Packages-Integration.ps1

Installs specific versions of KoreForge packages into the integration test project.

---

## CLI Tools

| Tool | Package | Description |
|---|---|---|
| `kf-settings` | `KoreForge.Settings.Cli` | Manage SQL-backed settings: list, get, set, delete, history, rollback, export, import |
| `jex` | `KF.Jex.Cli` | Evaluate JEX expressions from the command line, pipe JSON, use as a build/CI tool |

Install globally:

```bash
dotnet tool install -g KoreForge.Settings.Cli
dotnet tool install -g KF.Jex.Cli
```

See [50-Settings.md](50-Settings.md) and [11a-Jex-Cli.md](11a-Jex-Cli.md) for full CLI documentation.

---

# API Reference Documentation

This folder contains generated API reference documentation for each `KoreForge.*` package. The files are produced from the XML documentation embedded in each NuGet package and converted to LLM-readable Markdown.

---

## Package Reference Files

| File | Package | Contents |
|------|---------|----------|
| [KoreForge.Time.md](KoreForge.Time.md) | `KoreForge.Time` | `ISystemClock`, `VirtualSystemClock`, clock singletons |
| [KoreForge.Logging.md](KoreForge.Logging.md) | `KoreForge.Logging` | `LogEventSourceAttribute`, generated logger surface |
| [KoreForge.Metrics.md](KoreForge.Metrics.md) | `KoreForge.Metrics` | `IOperationMonitor`, `OperationScope`, `MonitoringSnapshot` |
| [KoreForge.Processing.md](KoreForge.Processing.md) | `KoreForge.Processing` | `Pipeline`, `Flow`, all steps and stage abstractions |
| [KoreForge.AppLifecycle.md](KoreForge.AppLifecycle.md) | `KoreForge.AppLifecycle` | `ILifecycleFlow`, `ApplicationLifecycleOptions`, events |
| [KoreForge.Kafka.md](KoreForge.Kafka.md) | `KoreForge.Kafka` | Consumer/Producer hosts, `IProducerBuffer`, policies |
| [KoreForge.Jex.md](KoreForge.Jex.md) | `KoreForge.Jex` | `Jex` class, transform methods |
| [KoreForge.Web.md](KoreForge.Web.md) | `KoreForge.Web` | Authorization, endpoint builder, `ICurrentUser` |
| [KoreForge.Settings.md](KoreForge.Settings.md) | `KoreForge.Settings` | `ISettingsService`, `IHistoryService`, `KFSettingsOptions` |
| [KoreForge.Data.md](KoreForge.Data.md) | `KoreForge.Data` | `AlertsDbContext`, entity model, registration |
| [KoreForge.OData.md](KoreForge.OData.md) | `KoreForge.OData` | Source generator, attributes, base controller, security |
| [KoreForge.Json.md](KoreForge.Json.md) | `KoreForge.Json` | `JsonMaterializer`, `RootPropertyClassifier` |

---

## Version Manifest

The file [`manifest.json`](manifest.json) records the package version each API reference file was generated from:

```json
{
    "generated": "2026-03-15T10:00:00Z",
    "packages": [
        { "package": "KoreForge.Time",        "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Logging",     "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Metrics",     "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Processing",  "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.AppLifecycle","version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Kafka",       "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Jex",         "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Web",         "version": "1.0.0", "source": "nupkg" }
    ]
}
```

Run `scr/collect-api-docs.ps1` to regenerate all files and update the manifest.

---

## How XML Docs Are Generated

### Step 1 — Enable XML generation in each project

Each library's `Directory.Build.props` includes:

```xml
<GenerateDocumentationFile>true</GenerateDocumentationFile>
```

The .NET SDK writes `{AssemblyName}.xml` alongside the DLL during build.

### Step 2 — Include XML files in NuGet packages

**Single-assembly packages** (Time, AppLifecycle, Jex, etc.): The XML file is automatically included in the NuGet package when `GenerateDocumentationFile=true` is set on the packable project.

**Multi-assembly bundler packages** (Processing, Kafka, Logging): The bundler `.csproj` uses `None Include=...` to explicitly include each sub-assembly's XML file alongside the DLL:

```xml
<!-- In KF.Processing.csproj (bundler) -->
<ItemGroup>
  <ProcessingAssemblies Include="$(MSBuildThisFileDirectory)..\KF.Processing.Pipelines\bin\$(Configuration)\net10.0\KF.Processing.Pipelines.dll" />
  <ProcessingAssemblies Include="$(MSBuildThisFileDirectory)..\KF.Processing.Pipelines\bin\$(Configuration)\net10.0\KF.Processing.Pipelines.xml" />
  <!-- ... repeat for each sub-assembly ... -->
</ItemGroup>
```

### Step 3 — Collect from NuGet packages

`scr/collect-api-docs.ps1` (in this repository) runs after each library publishes:

1. Locates each library's latest `.nupkg` in its `artifacts/` folder (or downloads from the NuGet feed)
2. Expands the `.nupkg` (it is a zip file)
3. Extracts `lib/net10.0/*.xml` files
4. Copies them to `doc/Api/{PackageName}/`
5. Writes `doc/Api/manifest.json` recording the package version alongside each file

### Step 4 — Convert to Markdown

`scr/generate-api-markdown.ps1` reads each XML file and produces the Markdown reference files in this folder. The XML format is:

```xml
<doc>
  <assembly><name>KF.Time</name></assembly>
  <members>
    <member name="T:KF.Time.ISystemClock">
      <summary>Abstracts the system clock...</summary>
    </member>
    <member name="P:KF.Time.ISystemClock.UtcNow">
      <summary>Returns the current UTC time.</summary>
    </member>
  </members>
</doc>
```

The generator groups by type (`T:`), then lists properties (`P:`), methods (`M:`), and fields (`F:`), producing a Markdown section per type.

### Step 5 — Version tracking

The `manifest.json` file permanently links each Markdown reference file to the exact NuGet package version it was generated from. When reviewing LLM-generated output, you can verify:

> "The LLM read `KoreForge.Time.md` which was generated from `KoreForge.Time 1.0.0`. The current deployed version is also `1.0.0`. The docs are accurate."

---

## Keeping Docs in Sync

After releasing any `KoreForge.*` package:

```powershell
# From KoreForge.Main root
.\bin\collect-api-docs.ps1     # extract XMLs from latest packages → doc/Api/xml/
.\bin\generate-api-markdown.ps1 # convert XMLs → Markdown reference files
git add doc/Api/
git commit -m "docs: regenerate API reference for KoreForge.Kafka 1.1.0"
```

The commit message should include the package and version that triggered the refresh.

---

## For LLMs

When using these files to understand a KoreForge API:

1. Read `manifest.json` first — verify the version matches what your code targets
2. Read the package's Markdown file for type signatures and parameter docs
3. Cross-reference with [../Introduction/](../Introduction/) for usage patterns and design context
4. If a type is not in the Markdown file, it is internal — do not attempt to use it

---

# KoreForge.AppLifecycle — API Reference

**Package**: `KoreForge.AppLifecycle`  |  **Assembly**: `KF.AppLifecycle.dll`  |  **Namespace**: `KoreForge.AppLifecycle`

---

## Registration

```csharp
// Extension method on IServiceCollection
builder.Services.AddApplicationLifecycleManager(Action<ApplicationLifecycleOptions> configure);
```

Registers:
- `ApplicationLifecycleHostedService` (startup + shutdown flows)
- `ScheduledTasksHostedService` (recurring scheduled flows)
- All flows and stages listed in the options

---

## `ApplicationLifecycleOptions` Class

```csharp
namespace KoreForge.AppLifecycle;

public sealed class ApplicationLifecycleOptions
{
    /// Register a startup flow by type. Flows run in registration order.
    public ApplicationLifecycleOptions AddStartupFlow<TFlow>()
        where TFlow : ILifecycleFlow;

    /// Register a shutdown flow by type. Flows run in registration order.
    public ApplicationLifecycleOptions AddShutdownFlow<TFlow>()
        where TFlow : ILifecycleFlow;

    /// Register a scheduled flow with a configuration callback.
    public ApplicationLifecycleOptions AddScheduledFlow<TFlow>(
        Action<ScheduleOptions> configure)
        where TFlow : ILifecycleFlow;
}
```

---

## `ILifecycleFlow` Interface

All lifecycle flows must implement this interface.

```csharp
namespace KoreForge.AppLifecycle;

public interface ILifecycleFlow
{
    /// Execute the flow. Called once for startup/shutdown, or on each trigger for scheduled flows.
    Task ExecuteAsync(CancellationToken cancellationToken);
}
```

---

## `ScheduleOptions` Class

Configuration for a scheduled flow.

```csharp
namespace KoreForge.AppLifecycle;

public sealed class ScheduleOptions
{
    /// Fixed interval between executions. Required unless Trigger is set.
    public TimeSpan Interval { get; set; }

    /// If true, execute the flow once immediately on startup before the first Interval delay.
    public bool RunOnStartup { get; set; }

    /// Custom trigger that replaces the fixed Interval. If set, Interval is ignored.
    public IScheduleTrigger? Trigger { get; set; }

    /// If true, the host will stop when this flow throws an unhandled exception.
    /// Default: false (exceptions are logged and the schedule continues).
    public bool AbortOnException { get; set; }
}
```

---

## `IScheduleTrigger` Interface

Custom trigger for scheduled flows.

```csharp
namespace KoreForge.AppLifecycle;

public interface IScheduleTrigger
{
    /// Wait until the next execution time.
    /// Implementations must honour cancellationToken.
    Task WaitAsync(CancellationToken cancellationToken);
}
```

---

## `IApplicationLifecycleEvents` Interface

Optional event hooks for monitoring or integrating with lifecycle transitions. Register one or more implementations via DI.

```csharp
namespace KoreForge.AppLifecycle;

public interface IApplicationLifecycleEvents
{
    // --- Startup ---
    Task OnBeforeStartupFlowsAsync(CancellationToken cancellationToken);
    Task OnAfterStartupFlowsAsync(CancellationToken cancellationToken);
    Task OnStartupFlowExecutingAsync(string flowName, CancellationToken cancellationToken);
    Task OnStartupFlowExecutedAsync(string flowName, TimeSpan duration, CancellationToken cancellationToken);

    // --- Shutdown ---
    Task OnBeforeShutdownFlowsAsync(CancellationToken cancellationToken);
    Task OnAfterShutdownFlowsAsync(CancellationToken cancellationToken);
    Task OnShutdownFlowExecutingAsync(string flowName, CancellationToken cancellationToken);
    Task OnShutdownFlowExecutedAsync(string flowName, TimeSpan duration, CancellationToken cancellationToken);
}
```

---

## `ApplicationLifecycleException` Class

Thrown when a startup or shutdown flow fails. Wraps the original exception.

```csharp
namespace KoreForge.AppLifecycle;

public sealed class ApplicationLifecycleException : Exception
{
    /// Name of the flow implementation type that failed.
    public string FlowName { get; }

    /// Whether the failure occurred in Startup or Shutdown.
    public LifecyclePhase Phase { get; }

    // InnerException contains the original exception from the flow.
}
```

---

## `LifecyclePhase` Enum

```csharp
namespace KoreForge.AppLifecycle;

public enum LifecyclePhase
{
    Startup,
    Shutdown
}
```

---

## `ApplicationLifecycleHostedService` Class

`IHostedService` that runs startup flows on `StartAsync` and shutdown flows on `StopAsync`. Registered automatically by `AddApplicationLifecycleManager`.

```csharp
namespace KoreForge.AppLifecycle;

public sealed class ApplicationLifecycleHostedService : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken);
    public Task StopAsync(CancellationToken cancellationToken);
}
```

---

## `ScheduledTasksHostedService` Class

`IHostedService` that manages the background loop for each registered scheduled flow. Registered automatically.

```csharp
namespace KoreForge.AppLifecycle;

public sealed class ScheduledTasksHostedService : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken);
}
```

---

# KoreForge.Data — API Reference

> Package: `KoreForge.Data` · Assembly: `KF.Data`

## Registration

```csharp
// Scoped DbContext
services.AddAlertsDb(Action<AlertsDbOptions> configure)
services.AddAlertsDb(string connectionString)

// Factory pattern
services.AddAlertsDbFactory(Action<AlertsDbOptions> configure)
services.AddAlertsDbFactory(string connectionString)
```

## `AlertsDbOptions`

```csharp
public sealed class AlertsDbOptions
{
    public const string SectionName = "AlertsDb";
    public string ConnectionString { get; set; } = string.Empty;
}
```

## `AlertsDbContext`

EF Core `DbContext` with scaffolded entities. Extend via partial class in `src/KF.Data/AlertsDbContext.cs`.

### Entity Sets

| DbSet | Entity Type | Namespace |
|-------|------------|-----------|
| `NotificationOutboxes` | `NotificationOutbox` | `KF.Data.Alerts.Notification` |
| `EmailPayloads` | `EmailPayload` | `KF.Data.Alerts.Notification` |
| `SmsPayloads` | `SmsPayload` | `KF.Data.Alerts.Notification` |
| `Channels` | `Channel` | `KF.Data.Alerts.Notification` |
| `Priorities` | `Priority` | `KF.Data.Alerts.Notification` |
| `OutboxStatuses` | `OutboxStatus` | `KF.Data.Alerts.Notification` |
| `SendOutcomes` | `SendOutcome` | `KF.Data.Alerts.Notification` |

### `NotificationOutbox`

Core entity with foreign keys to all lookup tables, retry tracking, and timestamps.

### Lookup Entities

`Channel`, `Priority`, `OutboxStatus`, `SendOutcome` — simple id + name pairs.

### Payload Entities

- `EmailPayload` — FromAddress, CcRecipients, BccRecipients, IsHtml
- `SmsPayload` — FromNumber, ProviderMessageId

## Scaffolding

```powershell
.\scr\scaffold.ps1
```

Generated code lives in `src/KF.Data/Generated/` — do not edit.

---

# KoreForge.Jex — API Reference

**Package**: `KoreForge.Jex`  |  **Assembly**: `KF.Jex.dll`  |  **Namespace**: `KoreForge.Jex`

---

## `Jex` Class

Stateless JSON transform engine. Thread-safe; create one instance and use it as a singleton.

```csharp
namespace KoreForge.Jex;

public sealed class Jex
{
    public Jex();

    /// Apply a Jex transform expression to a JSON input string.
    /// Returns the transformed result as a JSON string.
    /// Throws JexException on invalid transform or input.
    public string Transform(string transformJson, string inputJson);

    /// Apply a transform to a pre-parsed JsonDocument input.
    public string Transform(string transformJson, System.Text.Json.JsonDocument inputDoc);

    /// Apply one transform to multiple input documents.
    /// Processes inputs in declaration order; not parallelised internally.
    public IEnumerable<string> TransformMany(string transformJson, IEnumerable<string> inputJsonDocuments);
}
```

---

## `JexException` Class

Thrown by `Jex.Transform` when the expression cannot be evaluated.

```csharp
namespace KoreForge.Jex;

public sealed class JexException : Exception
{
    /// The expression fragment that caused the failure, if determinable.
    public string? Expression { get; }

    /// The path within the input document where evaluation failed, if applicable.
    public string? InputPath { get; }
}
```

**Common causes**:

| Condition | Exception message prefix |
|-----------|--------------------------|
| Malformed transform JSON | `"Transform JSON is not valid:"` |
| Malformed input JSON | `"Input JSON is not valid:"` |
| Undefined path (non-null-safe) | `"Path not found:"` |
| Type mismatch in arithmetic | `"Cannot apply operator"` |
| Unsupported expression key | `"Unknown Jex key:"` |

---

## DI Integration

```csharp
// Register as singleton (recommended)
builder.Services.AddSingleton<Jex>();

// Or use the extension method
builder.Services.AddJex();
```

---

## Expression Key Summary

| Key | Syntax | Description |
|-----|--------|-------------|
| Path reference | `"$in.a.b.c"` | Read nested field from input |
| Array index | `"$in.list[0]"` | Read indexed element |
| String interpolation | `"Hello $in.name!"` | Embed path in string literal |
| Comparison | `"$in.age >= 18"` | Boolean expression |
| Arithmetic | `"$in.price * 1.2"` | Numeric expression |
| Conditional | `{ "$if", "$then", "$else" }` | Ternary branch |
| Spread | `{ "$spread": "$in.obj", ... }` | Merge sub-object fields into output |
| Map | `{ "$map", "$as", "$body" }` | Project array elements |
| Filter | `{ "$filter", "$as", "$where" }` | Filter array elements |
| Coalesce | `{ "$coalesce": [...] }` | First non-null value |
| Literal | Any non-`$` value | Emitted verbatim (string, number, bool, array, object) |

See [../Introduction/04-JEX-DSL.md](../Introduction/04-JEX-DSL.md) for full syntax examples.

---

# KoreForge.Json — API Reference

> Package: `KoreForge.Json` · Assemblies: `KF.Json`, `KF.Json.Jex`

Zero KoreForge dependencies.

## `JsonMaterializer`

```csharp
public static class JsonMaterializer
{
    /// Expand escaped JSON strings in token.
    /// Returns a new tree — the original token is not mutated.
    public static JToken Expand(JToken token, JsonMaterializerOptions options)
}
```

## `JsonMaterializerOptions`

```csharp
public sealed class JsonMaterializerOptions
{
    /// Maximum recursion depth (default 10).
    public int MaxDepth { get; set; } = 10;

    /// Property names known to contain escaped JSON.
    /// When set, only these fields are probed.
    /// When null or empty, ALL string values are probed.
    public IReadOnlyList<string>? FieldHints { get; set; }
}
```

## `RootPropertyClassifier`

```csharp
public sealed class RootPropertyClassifier
{
    /// Build once at startup.
    public RootPropertyClassifier(
        string[] propertyNames,
        List<KeyValuePair<int, Regex>> matches)

    /// Classify raw UTF-8 bytes.
    /// Returns:
    ///   0  = no matching root property found
    ///  -1  = property found but no regex matched
    ///  -2  = invalid/empty input or error
    ///   n  = first matching regex's int key
    public int Classify(byte[] inputData)

    /// One-shot convenience method.
    public static int Classify(
        byte[] inputData,
        string[] propertyNames,
        List<KeyValuePair<int, Regex>> matches)
}
```

## `ExpandJsonFunction` (KF.Json.Jex)

```csharp
public sealed class ExpandJsonFunction : IJexFunction
{
    public string Name => "expandJson";

    /// args[0] = path (JPath string)
    /// args[1] = maxDepth (optional, default 10)
    public JToken Invoke(JToken input, JToken[] args)
}
```

JEX usage: `expandJson($.payload, 5)`

---

# KoreForge.Kafka — API Reference

**Package**: `KoreForge.Kafka`  |  **Namespace root**: `KoreForge.Kafka`

Multi-assembly package:

| Assembly | Namespace | Contents |
|----------|-----------|----------|
| `KF.Kafka.Consumer.dll` | `KoreForge.Kafka.Consumer` | `KafkaConsumerHost`, `IKafkaBatchProcessor` |
| `KF.Kafka.Producer.dll` | `KoreForge.Kafka.Producer` | `KafkaProducerHost`, `IProducerBuffer` |
| `KF.Kafka.AdminClient.dll` | `KoreForge.Kafka.AdminClient` | `KafkaAdminClient` |
| `KF.Kafka.Pipeline.dll` | `KoreForge.Kafka.Pipeline` | `KafkaPipelineProcessorBuilder` |
| `KF.Kafka.Configuration.dll` | `KoreForge.Kafka.Configuration` | Options, policy types |
| `KF.Kafka.Abstractions.dll` | `KoreForge.Kafka.Abstractions` | Shared interfaces |

---

## Consumer

### `IKafkaBatchProcessor` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IKafkaBatchProcessor
{
    /// Process a batch of Kafka messages.
    Task ProcessBatchAsync(
        IReadOnlyList<ConsumeResult<Ignore, string>> batch,
        CancellationToken cancellationToken);
}
```

### `KafkaConsumerHost` Class

`IHostedService` that polls Kafka and dispatches batches to `IKafkaBatchProcessor`. Registered automatically by `AddKafkaConsumer`.

```csharp
namespace KoreForge.Kafka.Consumer;

public sealed class KafkaConsumerHost : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken);
}
```

### `ConsumerOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ConsumerOptions
{
    public string        BootstrapServers  { get; set; }  // required
    public string        GroupId           { get; set; }  // required
    public List<string>  Topics            { get; set; }  // required
    public int           MaxBatchSize      { get; set; }  // default: 100
    public int           FlushIntervalMs   { get; set; }  // default: 50
    public AutoOffsetReset AutoOffsetReset { get; set; }  // default: Earliest
    public bool          EnableAutoCommit  { get; set; }  // default: false
    public int           SessionTimeoutMs  { get; set; }  // default: 30000

    /// Backpressure policy; default: no backpressure.
    public IBackpressurePolicy? Backpressure { get; set; }

    /// Restart policy on consumer loop failure; default: DefaultConsumerRestartPolicy.
    public IRestartPolicy? RestartPolicy { get; set; }
}
```

### Registration

```csharp
builder.Services.AddKafkaConsumer(Action<ConsumerOptions> configure);
builder.Services.AddScoped<IKafkaBatchProcessor, MyBatchProcessor>();
```

---

## Producer

### `IProducerBuffer` Interface

Enqueue messages for async batched publishing to Kafka.

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IProducerBuffer
{
    /// Enqueue a message to the default topic.
    ValueTask EnqueueAsync<T>(T message, CancellationToken cancellationToken);

    /// Enqueue a message to an explicit topic.
    ValueTask EnqueueAsync<T>(T message, string topic, CancellationToken cancellationToken);

    /// Enqueue with an explicit partition key.
    ValueTask EnqueueAsync<T>(T message, string topic, string partitionKey, CancellationToken cancellationToken);

    /// Current number of messages waiting to be flushed.
    int PendingCount { get; }
}
```

### `KafkaProducerHost` Class

`IHostedService` that batches messages from `IProducerBuffer` and flushes to Kafka. Registered automatically by `AddKafkaProducer`.

### `ProducerOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ProducerOptions
{
    public string BootstrapServers { get; set; }   // required
    public string DefaultTopic     { get; set; }   // required
    public int    MaxBatchSize     { get; set; }   // default: 200
    public int    LingerMs         { get; set; }   // default: 5
    public string? CompressionType { get; set; }  // "none" | "gzip" | "snappy" | "lz4"

    public IRestartPolicy? RestartPolicy { get; set; }
}
```

### Registration

```csharp
builder.Services.AddKafkaProducer(Action<ProducerOptions> configure);
// IProducerBuffer is registered automatically
```

---

## Pipeline Integration

### `KafkaPipelineProcessorBuilder`

Wires a `KoreForge.Processing` pipeline to the Kafka consumer batch.

```csharp
// Registration
builder.Services.AddKafkaPipelineProcessor(pb =>
{
    pb.UseMessagesPerBatch(500)
      .UseDeserializer<JsonMessageDeserializer<OrderMessage>>()
      .UsePipeline<OrderMessage>(pipeline => pipeline
          .AddStep<ValidateOrderStep>()
          .AddStep<EnrichOrderStep>()
          .AddStep<PersistOrderStep>());
});
```

The builder registers an `IKafkaBatchProcessor` implementation internally.

---

## Backpressure Policies

### `IBackpressurePolicy` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IBackpressurePolicy
{
    /// Returns true when Kafka polling should pause.
    bool ShouldPause(int queueDepth);

    /// Returns true when Kafka polling can resume after a pause.
    bool ShouldResume(int queueDepth);
}
```

### `ThresholdBackpressurePolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ThresholdBackpressurePolicy : IBackpressurePolicy
{
    /// Pause when queue depth exceeds this value. Default: 1000.
    public int PauseThreshold  { get; set; }

    /// Resume when queue depth drops below this value. Default: 200.
    public int ResumeThreshold { get; set; }
}
```

---

## Restart Policies

### `IRestartPolicy` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IRestartPolicy
{
    /// True if the host should attempt another restart.
    bool ShouldRestart(int attemptNumber, Exception exception);

    /// Delay before the next restart attempt.
    Task WaitAsync(int attemptNumber, CancellationToken cancellationToken);
}
```

### `FixedRetryRestartPolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class FixedRetryRestartPolicy : IRestartPolicy
{
    public int    MaxRetries    { get; set; }  // default: 5
    public int    DelayMs       { get; set; }  // default: 2000
    public double BackoffFactor { get; set; }  // default: 1.0 (linear); >1 = exponential
}
```

### `DefaultProducerRestartPolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class DefaultProducerRestartPolicy : IRestartPolicy
{
    public int MaxRetries { get; set; }  // default: 10
    public int DelayMs    { get; set; }  // default: 1000
}
```

---

## Admin Client

### `KafkaAdminClient` Class

```csharp
namespace KoreForge.Kafka.AdminClient;

public sealed class KafkaAdminClient : IAsyncDisposable
{
    /// Create a topic if it does not already exist.
    Task CreateTopicIfNotExistsAsync(
        string name,
        int    partitions,
        short  replicationFactor,
        CancellationToken cancellationToken = default);

    /// Delete a topic. Throws if the topic does not exist.
    Task DeleteTopicAsync(string name, CancellationToken cancellationToken = default);

    /// List all topics.
    Task<IReadOnlyList<string>> ListTopicsAsync(CancellationToken cancellationToken = default);

    public ValueTask DisposeAsync();
}
```

### `AdminClientOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class AdminClientOptions
{
    public string BootstrapServers { get; set; }  // required
}
```

### Registration

```csharp
builder.Services.AddKafkaAdminClient(Action<AdminClientOptions> configure);
```

---

# KoreForge.Logging — API Reference

**Package**: `KoreForge.Logging`

Multi-assembly package:

| Assembly | TFM | Contents |
|----------|-----|----------|
| `KF.Logging.Runtime.dll` | `net10.0` | Runtime logging helpers, DI extensions |
| `KF.Logging.Generator.dll` | `netstandard2.0` | Roslyn source generator |
| `KF.Logging.Analyzers.dll` | `netstandard2.0` | Roslyn analyzer (duplicate ID detection) |

---

## `LogEventSourceAttribute` Class

Decorate an enum with this attribute to trigger source generation.

```csharp
namespace KoreForge.Logging;

[AttributeUsage(AttributeTargets.Enum)]
public sealed class LogEventSourceAttribute : Attribute
{
    /// The name of the generated root logger type (e.g. "AppLogger").
    public string LoggerRootTypeName { get; set; }

    /// The top-level scope path prefix emitted with every log call (e.g. "MyApp").
    public string BasePath { get; set; }

    public LogEventSourceAttribute(string loggerRootTypeName, string basePath);
}
```

---

## Generated Logger Surface

Given the declaration:

```csharp
[LogEventSource("AppLogger", "MyApp")]
public enum LogEventIds
{
    APP_Startup = 1000,
    DB_Query_Execute = 2000,
}
```

The source generator emits an `AppLogger` class with the following shape (simplified):

```csharp
// Auto-generated — do not edit
public sealed class AppLogger
{
    public AppLogger(ILogger<AppLogger> logger) { ... }

    public AppScope App { get; }

    public sealed class AppScope
    {
        public StartupScope Startup { get; }

        public sealed class StartupScope
        {
            // Wraps ILogger; adds EventPath scope and EventId on every call
            public void LogTrace(string message, params object?[] args);
            public void LogDebug(string message, params object?[] args);
            public void LogInformation(string message, params object?[] args);
            public void LogWarning(string message, params object?[] args);
            public void LogError(Exception? ex, string message, params object?[] args);
            public void LogCritical(Exception? ex, string message, params object?[] args);
        }
    }

    public DbScope Db { get; }

    public sealed class DbScope
    {
        public QueryScope Query { get; }

        public sealed class QueryScope
        {
            public ExecuteScope Execute { get; }

            public sealed class ExecuteScope
            {
                public void LogDebug(string message, params object?[] args);
                // ... other levels
            }
        }
    }
}
```

Each leaf `Log*` call automatically adds two log scopes:
- `EventPath` = `"MyApp.DB.Query.Execute"`
- `EventId` = `2000`

---

## DI Registration

```csharp
namespace KoreForge.Logging;

// Extension method on IServiceCollection
public static IServiceCollection AddGeneratedLogging(this IServiceCollection services);
// Registers AppLogger (or the LoggerRootTypeName) as a scoped service.
```

Usage:

```csharp
builder.Services.AddLogging(lb => lb.AddConsole());
builder.Services.AddGeneratedLogging();

// Inject
public class OrderService(AppLogger log)
{
    public void Start() => log.App.Startup.LogInformation("Service starting");
}
```

---

## `KoreForge.Logging.Serilog` — `AddKoreForgeSerilogLogging`

```csharp
namespace KoreForge.Logging.Serilog;

builder.Services.AddKoreForgeSerilogLogging(Action<SerilogLoggingOptions> configure);
```

### `SerilogLoggingOptions` Class

```csharp
public sealed class SerilogLoggingOptions
{
    /// Write structured logs to stdout. Default: true.
    public bool WriteToConsole { get; set; }

    /// LogStash/Elasticsearch sink configuration. Null = disabled.
    public LogStashOptions? LogStash { get; set; }

    /// Minimum log level. Default: Information.
    public LogEventLevel MinimumLevel { get; set; }
}
```

### `LogStashOptions` Class

```csharp
public sealed class LogStashOptions
{
    public string Host    { get; set; }   // required
    public int    Port    { get; set; }   // required
    public string AppName { get; set; }   // required — identifies the service in ELK
    public bool   UseTls  { get; set; }  // default: false
}
```

---

# KoreForge.Metrics — API Reference

**Package**: `KoreForge.Metrics`  |  **Assembly**: `KF.Metrics.dll`  |  **Namespace**: `KoreForge.Metrics`

---

## `IOperationMonitor` Interface

Main entry point for recording operation timing and outcome.

```csharp
namespace KoreForge.Metrics;

public interface IOperationMonitor
{
    /// Begin timing a named operation with optional tags.
    /// Returns a disposable scope — dispose to record the completed duration.
    OperationScope Begin(string operationName);
    OperationScope Begin(string operationName, OperationTags tags);
}
```

---

## `OperationScope` Class

Disposable timing scope. Dispose to stop timing and record the result.

```csharp
namespace KoreForge.Metrics;

public sealed class OperationScope : IDisposable
{
    /// Mark the operation as failed before disposing.
    /// If not called, the operation is recorded as successful.
    public void MarkFailed();

    /// Record additional tags after the scope was opened.
    public void AddTag(string key, string value);

    /// Stop timing and record the operation. Called automatically by Dispose().
    public void Dispose();
}
```

**Pattern**:
```csharp
using var scope = monitor.Begin("my-operation");
try   { await DoWorkAsync(); }
catch { scope.MarkFailed(); throw; }
// Dispose() records success/failure + duration
```

---

## `OperationTags` Class

Immutable key/value tag bag for categorising operations.

```csharp
namespace KoreForge.Metrics;

public sealed class OperationTags : IReadOnlyDictionary<string, string>
{
    public static readonly OperationTags Empty;

    /// Construct from collection initialiser:
    /// new OperationTags { { "region", "eu-west" }, { "tier", "gold" } }
    public void Add(string key, string value);

    // IReadOnlyDictionary<string, string> members
    public string this[string key]  { get; }
    public IEnumerable<string> Keys   { get; }
    public IEnumerable<string> Values { get; }
    public int Count                  { get; }
    public bool ContainsKey(string key);
    public bool TryGetValue(string key, out string value);
}
```

---

## `IMonitoringSnapshotProvider` Interface

Produces point-in-time aggregate metrics.

```csharp
namespace KoreForge.Metrics;

public interface IMonitoringSnapshotProvider
{
    /// Returns the current aggregate snapshot.
    MonitoringSnapshot GetSnapshot();
}
```

---

## `MonitoringSnapshot` Class

Aggregate view of all recorded operations and system metrics.

```csharp
namespace KoreForge.Metrics;

public sealed class MonitoringSnapshot
{
    /// Timestamp when this snapshot was produced.
    public DateTimeOffset Timestamp { get; }

    /// Per-operation aggregates, keyed by operation name.
    public IReadOnlyDictionary<string, OperationAggregate> Operations { get; }

    /// Time-series buckets for trending.
    public IReadOnlyList<MetricBucket> Buckets { get; }

    /// Process CPU usage at snapshot time (0.0 – 1.0 per core).
    public double CpuUsage { get; }

    /// Approximate working set in bytes.
    public long MemoryBytes { get; }

    /// Get the aggregate for a specific operation (or null if not recorded).
    public OperationAggregate? GetOperation(string name);
}
```

---

## `OperationAggregate` Class

Aggregated statistics for a single operation name.

```csharp
namespace KoreForge.Metrics;

public sealed class OperationAggregate
{
    public string OperationName { get; }

    /// Total calls recorded in the retention window.
    public long TotalCount { get; }

    /// Calls that completed without MarkFailed().
    public long SuccessCount { get; }

    /// Calls where MarkFailed() was called.
    public long FailureCount { get; }

    /// Success rate (0.0 – 1.0).
    public double SuccessRate { get; }

    /// Mean duration across all calls in the window.
    public TimeSpan AverageDuration { get; }

    /// Minimum recorded duration.
    public TimeSpan MinDuration { get; }

    /// Maximum recorded duration.
    public TimeSpan MaxDuration { get; }

    /// 95th percentile duration.
    public TimeSpan P95Duration { get; }

    /// Currently active (in-progress) operations.
    public int ActiveCount { get; }
}
```

---

## `IOperationEventSink` Interface

Optional callback for reacting to completed operations (e.g. slow-operation alerting).

```csharp
namespace KoreForge.Metrics;

public interface IOperationEventSink
{
    /// Called asynchronously after each operation completes.
    /// Must not throw; exceptions are swallowed by the metrics engine.
    Task OnOperationCompletedAsync(OperationCompletedContext context);
}
```

---

## `OperationCompletedContext` Record

Context passed to `IOperationEventSink.OnOperationCompletedAsync`.

```csharp
namespace KoreForge.Metrics;

public sealed record OperationCompletedContext
{
    public string         OperationName { get; init; }
    public TimeSpan       Duration      { get; init; }
    public bool           IsSuccess     { get; init; }
    public OperationTags  Tags          { get; init; }
    public DateTimeOffset CompletedAt   { get; init; }
}
```

---

## `MonitoringTimeMode` Enum

```csharp
namespace KoreForge.Metrics;

public enum MonitoringTimeMode
{
    Utc,
    Local
}
```

---

## `MonitoringOptions` Class

Passed to `AddKoreForgeMetrics(options => ...)`.

```csharp
namespace KoreForge.Metrics;

public sealed class MonitoringOptions
{
    /// Whether to use UTC or local time for bucket timestamps. Default: Utc.
    public MonitoringTimeMode TimeMode { get; set; }

    /// Fraction of operations to record (1 = all, 0.5 = 50%). Default: 1.
    public double SamplingRate { get; set; }

    /// Number of time-series buckets to retain. Default: 60 (1 hour at 1-min buckets).
    public int BucketCount { get; set; }

    /// Duration of each bucket. Default: 1 minute.
    public TimeSpan BucketDuration { get; set; }
}
```

---

## Registration

```csharp
// Minimal
builder.Services.AddKoreForgeMetrics();

// With options
builder.Services.AddKoreForgeMetrics(options =>
{
    options.TimeMode       = MonitoringTimeMode.Utc;
    options.SamplingRate   = 1.0;
    options.BucketCount    = 60;
    options.BucketDuration = TimeSpan.FromMinutes(1);
});

// Optional: event sink for slow-operation alerting
builder.Services.AddSingleton<IOperationEventSink, PagerDutyAlertSink>();
```

---

## `KoreForge.Metrics.AspNet` — `MapMonitoringEndpoints`

```csharp
// Registers HTTP endpoint(s)
app.MapMonitoringEndpoints("/monitoring");
// GET /monitoring/snapshot  → MonitoringSnapshot (JSON)
```

---

# KoreForge.OData — API Reference

> Package: `KoreForge.OData` · Assemblies: `KF.OData`, `KF.OData.Generators`

## Registration

```csharp
IMvcBuilder AddKoreForgeOData(
    this IMvcBuilder mvcBuilder,
    Action<KoreForgeODataOptions>? configureOptions = null)

IServiceCollection AddEdmModelConfigurator<TConfigurator>(
    this IServiceCollection services)
    where TConfigurator : class, IEdmModelConfigurator
```

## `KoreForgeODataOptions`

```csharp
public sealed class KoreForgeODataOptions
{
    public int MaxPageSize { get; set; } = 100;
    public int MaxExpandDepth { get; set; } = 3;
    public int MaxNodeCount { get; set; } = 100;
    public bool EnableCount { get; set; } = true;
    public bool EnableFilter { get; set; } = true;
    public bool EnableOrderBy { get; set; } = true;
    public bool EnableSelect { get; set; } = true;
    public bool EnableExpand { get; set; } = true;
    public string RoutePrefix { get; set; } = "odata";
}
```

## Attributes

### `[ODataAuthorize]`

```csharp
public sealed class ODataAuthorizeAttribute : Attribute
{
    public string? ReadPolicy { get; set; }
    public string? CreatePolicy { get; set; }
    public string? UpdatePolicy { get; set; }
    public string? DeletePolicy { get; set; }
    public string? Roles { get; set; }
}
```

### `[ODataIgnore]`

```csharp
public sealed class ODataIgnoreAttribute : Attribute { }
```

### `[ODataPropertyRestriction]`

```csharp
public sealed class ODataPropertyRestrictionAttribute : Attribute
{
    public bool DenyRead { get; set; }
    public bool DenyPatch { get; set; }
    public bool DenyPut { get; set; }
    public bool DenySerialization { get; set; }
}
```

## `IEdmModelConfigurator`

```csharp
public interface IEdmModelConfigurator
{
    string ContextPrefix { get; }
    void Configure(ODataConventionModelBuilder builder);
}
```

## `KoreForgeODataController<TContext, TEntity, TKey>`

Base controller providing full CRUD with authorization and row-level filtering.

### Operations

| Method | Route | Description |
|--------|-------|-------------|
| `Get()` | `GET /odata/{prefix}/{set}` | Query with OData filters |
| `Get(key)` | `GET /odata/{prefix}/{set}({key})` | Single entity |
| `Post(entity)` | `POST /odata/{prefix}/{set}` | Create |
| `Put(key, entity)` | `PUT /odata/{prefix}/{set}({key})` | Full replace |
| `Patch(key, delta)` | `PATCH /odata/{prefix}/{set}({key})` | Partial update |
| `Delete(key)` | `DELETE /odata/{prefix}/{set}({key})` | Delete |

### Virtual Lifecycle Hooks

```csharp
OnBeforeQuery, OnBeforeSingleResult,
OnBeforeCreate, OnAfterCreate,
OnBeforeReplace, OnAfterReplace,
OnBeforePatch, OnAfterPatch,
OnBeforeDelete, OnAfterDelete
```

## Security

### `ODataEntityAuthorizationInfo`

```csharp
public sealed class ODataEntityAuthorizationInfo
{
    public string? ReadPolicy { get; init; }
    public string? CreatePolicy { get; init; }
    public string? UpdatePolicy { get; init; }
    public string? DeletePolicy { get; init; }
    public string[]? Roles { get; init; }

    public static ODataEntityAuthorizationInfo? FromEntityType(Type entityType)
    public Task<bool> IsAuthorizedAsync(
        IAuthorizationService authorizationService,
        ClaimsPrincipal user,
        ODataOperation operation)
}

public enum ODataOperation { Read, Create, Update, Delete }
```

### `IRowLevelFilterProvider<TEntity>`

```csharp
public interface IRowLevelFilterProvider<TEntity> where TEntity : class
{
    IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query);
}
```

### `PropertyRestrictionResolver`

```csharp
public static class PropertyRestrictionResolver
{
    public static IReadOnlySet<string> GetPatchDeniedProperties(Type entityType)
    public static IReadOnlySet<string> GetPutDeniedProperties(Type entityType)
    public static IReadOnlySet<string> GetReadDeniedProperties(Type entityType)
}
```

## Source Generator

`ODataSourceGenerator` is an `IIncrementalGenerator` that:

1. Scans for `[assembly: GenerateODataFor(typeof(TContext))]`
2. Analyzes each `DbContext` using `DbContextAnalyzer`
3. Emits one controller per non-ignored entity via `ControllerEmitter`
4. Emits one `IEdmModelConfigurator` per schema group via `EdmConfiguratorEmitter`

---

# KoreForge.Processing — API Reference

**Package**: `KoreForge.Processing`  |  **Namespaces**: see below

Multi-assembly package:

| Assembly | Namespace | Contents |
|----------|-----------|----------|
| `KF.Processing.Pipeline.dll` | `KoreForge.Processing.Pipeline` | `Pipeline` builder, `IPipeline<TIn,TOut>` |
| `KF.Processing.Pipeline.Abstractions.dll` | `KoreForge.Processing.Pipeline.Abstractions` | `IPipelineStep<TIn,TOut>`, `IPipelineContext` |
| `KF.Processing.Flow.dll` | `KoreForge.Processing.Flow` | `Flow` builder, `IFlow<TContext>` |
| `KF.Processing.Flow.Abstractions.dll` | `KoreForge.Processing.Flow.Abstractions` | `IFlowStage<TContext>`, `IFlowContext` |
| `KF.Processing.Pipelines.dll` | `KoreForge.Processing.Pipelines` | Built-in pipeline composite types |

---

## Pipeline Abstractions

### `IPipelineStep<TIn, TOut>` Interface

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipelineStep<TIn, TOut>
{
    /// Execute this step: transform input to output.
    Task<TOut> ExecuteAsync(TIn input, IPipelineContext context, CancellationToken cancellationToken);
}
```

### `IPipelineContext` Interface

Flows through all steps in a pipeline execution; provides DI and cross-step state.

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipelineContext
{
    /// Resolve a service from DI mid-pipeline.
    T GetService<T>() where T : notnull;

    /// Per-execution property bag for cross-step data.
    IDictionary<string, object?> Properties { get; }

    /// Propagated cancellation token for the pipeline execution.
    CancellationToken CancellationToken { get; }
}
```

### `IPipeline<TIn, TOut>` Interface

Represents a built, executable pipeline.

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipeline<TIn, TOut>
{
    /// Execute all steps in order, starting with input, returning the final output.
    Task<TOut> ExecuteAsync(TIn input, CancellationToken cancellationToken);

    /// Execute with explicit initial context (for property pre-seeding).
    Task<TOut> ExecuteAsync(TIn input, IPipelineContext context, CancellationToken cancellationToken);
}
```

---

## Pipeline Builder

### `Pipeline` Static Class

Entry point for building pipelines.

```csharp
namespace KoreForge.Processing.Pipeline;

public static class Pipeline
{
    /// Start building a pipeline with the given input type.
    /// Steps are resolved from DI when the pipeline is built with a service provider.
    public static IPipelineBuilder<T, T> Start<T>(IServiceProvider? serviceProvider = null);
}
```

### `IPipelineBuilder<TIn, TOut>` Interface

Fluent builder returned by `Pipeline.Start<T>()`.

```csharp
namespace KoreForge.Processing.Pipeline;

public interface IPipelineBuilder<TIn, TOut>
{
    /// Add a step whose output type becomes the new TOut.
    IPipelineBuilder<TIn, TNext> AddStep<TStep, TNext>()
        where TStep : IPipelineStep<TOut, TNext>;

    /// Shorthand when step type parameters can be inferred.
    IPipelineBuilder<TIn, TNext> AddStep<TStep>()
        where TStep : IPipelineStep<TOut, TNext>;

    /// Build the pipeline into an executable IPipeline<TIn, TOut>.
    IPipeline<TIn, TOut> Build();
}
```

---

## Flow Abstractions

### `IFlowStage<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlowStage<TContext>
{
    /// Execute this stage; mutate context in place.
    Task ExecuteAsync(TContext context, IFlowContext flowContext, CancellationToken cancellationToken);
}
```

### `IFlowContext` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlowContext
{
    /// Name assigned to this flow instance.
    string FlowName { get; }

    /// Zero-based index of the currently executing stage.
    int CurrentStageIndex { get; }

    /// Name of the currently executing stage (type name by default).
    string CurrentStageName { get; }

    /// Resolve additional services from DI.
    T GetService<T>() where T : notnull;

    /// Per-execution property bag.
    IDictionary<string, object?> Properties { get; }
}
```

### `IFlow<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlow<TContext>
{
    /// Execute all stages in order, passing context to each.
    Task ExecuteAsync(TContext context, CancellationToken cancellationToken);
}
```

---

## Flow Builder

### `Flow` Static Class

```csharp
namespace KoreForge.Processing.Flow;

public static class Flow
{
    /// Start building a named flow with the given context type.
    public static IFlowBuilder<TContext> Create<TContext>(
        string flowName,
        IServiceProvider? serviceProvider = null);
}
```

### `IFlowBuilder<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow;

public interface IFlowBuilder<TContext>
{
    /// Add a stage; resolved from DI.
    IFlowBuilder<TContext> AddStage<TStage>()
        where TStage : IFlowStage<TContext>;

    /// Add a stage instance directly (no DI resolution).
    IFlowBuilder<TContext> AddStage(IFlowStage<TContext> stage);

    /// Build into an executable IFlow<TContext>.
    IFlow<TContext> Build();
}
```

---

## Built-in Pipeline Types (`KoreForge.Processing.Pipelines`)

### `BatchPipeline<TIn, TOut>`

Processes a collection of items through a shared pipeline in parallel or sequential mode.

```csharp
namespace KoreForge.Processing.Pipelines;

public sealed class BatchPipeline<TIn, TOut>
{
    public BatchPipeline(IPipeline<TIn, TOut> inner, BatchPipelineOptions options);

    /// Process all items in the batch. Returns results in input order.
    Task<IReadOnlyList<TOut>> ExecuteAsync(
        IReadOnlyList<TIn> items,
        CancellationToken cancellationToken);
}

public sealed class BatchPipelineOptions
{
    /// Maximum degree of parallelism. Default: 1 (sequential).
    public int MaxDegreeOfParallelism { get; set; }

    /// Whether to continue processing remaining items when one fails. Default: false.
    public bool ContinueOnError { get; set; }
}
```

---

## Exceptions

### `PipelineException`

Thrown when a pipeline step fails.

```csharp
namespace KoreForge.Processing.Pipeline;

public sealed class PipelineException : Exception
{
    /// Name of the step that threw.
    public string StepName { get; }

    /// Zero-based index of the failing step.
    public int StepIndex { get; }
}
```

### `FlowException`

Thrown when a flow stage fails.

```csharp
namespace KoreForge.Processing.Flow;

public sealed class FlowException : Exception
{
    public string FlowName    { get; }
    public string StageName   { get; }
    public int    StageIndex  { get; }
}
```

---

# KoreForge.Settings — API Reference

> Package: `KoreForge.Settings` · Assemblies: `KF.Settings`, `KF.Settings.Abstractions`, `KF.Settings.Core`, `KF.Settings.Data`, `KF.Settings.Encryption`, `KF.Settings.Metrics`, `KF.Settings.Cli`

## Registration

```csharp
// Configuration source
builder.Configuration.AddKFSettings(Action<KFSettingsOptions> configure)

// DI services
builder.Services.AddKFSettingsServices(IConfiguration configuration)
```

## `KFSettingsOptions`

```csharp
public sealed class KFSettingsOptions
{
    public string ConnectionString { get; set; }
    public string? ApplicationId { get; set; }
    public string? InstanceId { get; set; }
    public TimeSpan PollingInterval { get; set; } = TimeSpan.FromSeconds(60);
    public BinaryEncoding BinaryEncoding { get; set; } = BinaryEncoding.Base64Url;
    public bool FailFastOnStartup { get; set; } = true;
    public bool EnableDecryption { get; set; }
    public bool EnableMetrics { get; set; } = true;
    public bool EnableDetailedLogging { get; set; }
}
```

## `ISettingsService`

```csharp
public interface ISettingsService
{
    Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct);
    Task<SettingRow?> GetAsync(long id, CancellationToken ct);
    Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct);
    Task DeleteAsync(long id, string changedBy, byte[] expectedRowVersion, CancellationToken ct);
}
```

## `IHistoryService`

```csharp
public interface IHistoryService
{
    Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct);
    Task RollbackAsync(string key, int versionIndex, string changedBy, CancellationToken ct);
}
```

## `IEncryptionProvider`

```csharp
public interface IEncryptionProvider
{
    string Encrypt(string plainText);
    string Decrypt(string cipherText);
}
```

Default: `NoOpEncryptionProvider` (pass-through). Register custom implementation when `EnableDecryption = true`.

## `IBinarySettingsAccessor`

```csharp
public interface IBinarySettingsAccessor
{
    Task<byte[]?> GetBinaryAsync(string key, CancellationToken ct);
    Task SetBinaryAsync(string key, byte[] data, string changedBy, CancellationToken ct);
}
```

## `IHealthReporter`

```csharp
public interface IHealthReporter
{
    DateTimeOffset? LastSuccessfulReloadUtc { get; }
    int ConsecutiveFailures { get; }
    int LastRowCount { get; }
}
```

## Connection String Resolution

1. `KFSettingsOptions.ConnectionString`
2. `ConnectionStrings:KFSettings`
3. `KF:Settings:ConnectionString`
4. `KF_SETTINGS_CONNECTIONSTRING` environment variable

## CLI Tool

```
kf-settings list|get|set|delete|history|rollback|export|import
  --application <id>
  --connection <connstr>
  --key <key>
  --value <value>
  --version <int>
```

---

# KoreForge.Time — API Reference

**Package**: `KoreForge.Time`  |  **Assembly**: `KF.Time.dll`  |  **Namespace**: `KF.Time`

---

## `ISystemClock` Interface

Abstracts the system clock for testable time-dependent code.

```csharp
namespace KF.Time;

public interface ISystemClock
{
    /// Current local time.
    DateTimeOffset Now { get; }

    /// Current UTC time.
    DateTimeOffset UtcNow { get; }

    /// High-resolution timestamp in Stopwatch ticks (matches Stopwatch.GetTimestamp() frequency).
    long TimestampTicks { get; }
}
```

---

## `LocalSystemClock` Class

Returns the machine's local time. Thread-safe singleton.

```csharp
namespace KF.Time;

public sealed class LocalSystemClock : ISystemClock
{
    /// Shared singleton instance.
    public static readonly LocalSystemClock Instance;

    public DateTimeOffset Now         { get; }  // DateTimeOffset.Now
    public DateTimeOffset UtcNow      { get; }  // DateTimeOffset.UtcNow
    public long           TimestampTicks { get; }
}
```

---

## `UtcSystemClock` Class

Returns UTC time. Thread-safe singleton.

```csharp
namespace KF.Time;

public sealed class UtcSystemClock : ISystemClock
{
    /// Shared singleton instance.
    public static readonly UtcSystemClock Instance;

    public DateTimeOffset Now         { get; }  // DateTimeOffset.UtcNow
    public DateTimeOffset UtcNow      { get; }  // DateTimeOffset.UtcNow
    public long           TimestampTicks { get; }
}
```

---

## `VirtualSystemClock` Class

A manually-controlled clock for deterministic unit testing. **Not thread-safe** — intended for single-threaded test use.

```csharp
namespace KF.Time;

public sealed class VirtualSystemClock : ISystemClock
{
    /// Initialise with a starting time.
    public VirtualSystemClock(DateTimeOffset startTime);

    /// Current (virtual) local time.
    public DateTimeOffset Now         { get; }

    /// Current (virtual) UTC time.
    public DateTimeOffset UtcNow      { get; }

    /// Virtual timestamp ticks, advanced proportionally with Advance().
    public long           TimestampTicks { get; }

    /// Advance the clock forward by the given duration.
    /// Throws ArgumentOutOfRangeException if duration is negative.
    public void Advance(TimeSpan duration);

    /// Set the clock to an absolute time.
    /// Throws ArgumentOutOfRangeException if newTime is before the current virtual time.
    public void Set(DateTimeOffset newTime);
}
```

### Exceptions

| Method | Exception | When |
|--------|-----------|------|
| `Advance(TimeSpan)` | `ArgumentOutOfRangeException` | `duration < TimeSpan.Zero` |
| `Set(DateTimeOffset)` | `ArgumentOutOfRangeException` | `newTime < current UtcNow` |

---

## `SystemClock` Static Class

A convenience static accessor.

```csharp
namespace KF.Time;

public static class SystemClock
{
    /// Current default instance. Defaults to LocalSystemClock.Instance.
    /// Can be replaced globally (e.g., in test bootstrapping).
    public static ISystemClock Instance { get; set; }
}
```

---

## Usage Examples

```csharp
// Production DI registration
builder.Services.AddSingleton<ISystemClock>(LocalSystemClock.Instance);

// UTC-only service
builder.Services.AddSingleton<ISystemClock>(UtcSystemClock.Instance);

// Test — deterministic time
var clock = new VirtualSystemClock(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));
clock.Advance(TimeSpan.FromHours(2));
Assert.Equal(2, clock.UtcNow.Hour);

// High-resolution duration measurement
long start = clock.TimestampTicks;
// ... work ...
long elapsed = clock.TimestampTicks - start;
double ms = elapsed * 1000.0 / Stopwatch.Frequency;
```

---

# KoreForge.Web — API Reference

**Package**: `KoreForge.Web`  |  **Namespace**: `KoreForge.Web`

---

## Registration

```csharp
// Full registration (authorization + API framework)
builder.Services.AddKoreForgeWeb(Action<KoreForgeWebOptions>? configure = null);
```

### `KoreForgeWebOptions` Class

```csharp
namespace KoreForge.Web;

public sealed class KoreForgeWebOptions
{
    /// Wrap all endpoint responses in a { success, data, error } envelope. Default: true.
    public bool EnableResponseEnvelopes { get; set; }

    /// Map KoreForgeException subtypes to HTTP status codes. Default: true.
    public bool EnableProblemDetails { get; set; }
}
```

---

## Authorization

### `AddKoreForgeAuthorization`

```csharp
namespace KoreForge.Web.Authorization;

// Extension on IServiceCollection
builder.Services.AddKoreForgeAuthorization(Action<KoreForgeAuthorizationOptions> configure);
```

### `KoreForgeAuthorizationOptions` Class

```csharp
public sealed class KoreForgeAuthorizationOptions
{
    /// Add a named authorization policy.
    public KoreForgeAuthorizationOptions AddPolicy(string name, Action<AuthorizationPolicyBuilder> build);
}
```

### `ICurrentUser` Interface

Abstracts the caller's identity for testability.

```csharp
namespace KoreForge.Web.Authorization;

public interface ICurrentUser
{
    /// The authenticated user's unique identifier (sub claim).
    string UserId { get; }

    /// The tenant identifier (tenant_id claim), or null if not present.
    string? TenantId { get; }

    /// All roles assigned to the current user.
    IEnumerable<string> Roles { get; }

    /// Returns true if the user has the specified claim with the given value.
    bool HasClaim(string claimType, string claimValue);

    /// Returns true if the user is in the given role.
    bool IsInRole(string role);
}
```

### Registration

```csharp
// Registers ICurrentUser backed by HttpContext.User
builder.Services.AddKoreForgeCurrentUser();
```

### `RequireResourceOwner` Extension

```csharp
namespace KoreForge.Web.Authorization;

// Extension on IEndpointConventionBuilder
endpoint.RequireResourceOwner(Func<HttpContext, string?> resourceIdExtractor);
```

Returns HTTP 403 if the resource ID extracted from the request does not match `ICurrentUser.UserId`.

---

## REST API Framework

### `MapKoreForgeEndpoints`

```csharp
namespace KoreForge.Web;

// Extension on IEndpointRouteBuilder
app.MapKoreForgeEndpoints(Action<IKoreForgeEndpointBuilder> configure);
```

### `IKoreForgeEndpointBuilder` Interface

```csharp
namespace KoreForge.Web;

public interface IKoreForgeEndpointBuilder
{
    IEndpointConventionBuilder Get<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Post<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Put<TRequest, TResponse>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Delete<TRequest>(
        string pattern,
        Delegate handler);

    IEndpointConventionBuilder Patch<TRequest, TResponse>(
        string pattern,
        Delegate handler);
}
```

---

## Response Envelope

All responses from `MapKoreForgeEndpoints` handlers use this envelope when `EnableResponseEnvelopes = true`:

```csharp
namespace KoreForge.Web;

public sealed class ApiResponse<T>
{
    public bool   Success { get; init; }
    public T?     Data    { get; init; }
    public ApiError? Error { get; init; }
}

public sealed class ApiError
{
    public string          Code    { get; init; }
    public string          Message { get; init; }
    public IList<string>?  Details { get; init; }
}
```

---

## Validation

### `IValidatable` Interface

```csharp
namespace KoreForge.Web;

public interface IValidatable
{
    ValidationResult Validate();
}
```

### `ValidationResult` Class

```csharp
namespace KoreForge.Web;

public sealed class ValidationResult
{
    public bool   IsValid  { get; }
    public string? Code    { get; }
    public string? Message { get; }
    public IReadOnlyList<string> Details { get; }

    public static ValidationResult Ok();
    public static ValidationResult Fail(string code, string message, params string[] details);
}
```

---

## Exception Mapping

`AddKoreForgeWebExceptionHandling()` maps:

| Exception Type | HTTP Status |
|----------------|-------------|
| `NotFoundException` | 404 Not Found |
| `ValidationException` | 422 Unprocessable Entity |
| `AuthorizationException` | 403 Forbidden |
| `ConflictException` | 409 Conflict |
| `KoreForgeException` (base) | 500 Internal Server Error |

```csharp
// Extension on IServiceCollection
builder.Services.AddKoreForgeWebExceptionHandling();
```

---

## `KoreForgeException` Hierarchy

```csharp
namespace KoreForge.Web;

public class KoreForgeException : Exception
{
    public string ErrorCode { get; }
    public KoreForgeException(string errorCode, string message);
    public KoreForgeException(string errorCode, string message, Exception inner);
}

public class NotFoundException       : KoreForgeException { ... }
public class ValidationException     : KoreForgeException { ... }
public class AuthorizationException  : KoreForgeException { ... }
public class ConflictException       : KoreForgeException { ... }
```




