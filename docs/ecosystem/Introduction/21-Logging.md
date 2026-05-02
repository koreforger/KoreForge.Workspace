# KoreForge.Logging

| | |
|---|---|
| **Package** | `KoreForge.Logging` |
| **Namespace** | `KoreForge.Logging` |
| **Source** | `KoreForge.Logging/src/` (Runtime, Generator, Analyzers) |
| **Tests** | `KoreForge.Logging/tst/KoreForge.Logging.Tests/` |
| **Dependencies** | KoreForge.Metrics, KoreForge.Time |

## Problem

Structured logging in large systems degrades into chaos. Teams invent their own event IDs, log message formats, and severity conventions. There is no discoverability — you cannot ask "what are all the log events this application emits?" without reading every line of source code. When event ID 1001 in Service A means "order received" and event ID 1001 in Service B means "cache miss," correlation across services becomes guesswork.

## Solution

KoreForge.Logging uses Roslyn source generation to produce log methods from an enum hierarchy. You define your log events once as nested enums + attributes. The source generator produces strongly-typed extension methods with deterministic event IDs derived from the hierarchy. The result: every log event has a unique, discoverable, type-safe entry point.

The assembly ships in three parts:
- `KoreForge.Logging.Runtime.dll` — runtime types and base interfaces
- `KoreForge.Logging.Generator.dll` (netstandard2.0) — Roslyn source generator that emits log methods at compile time
- `KoreForge.Logging.Analyzers.dll` — Roslyn analyzers that enforce logging conventions

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
