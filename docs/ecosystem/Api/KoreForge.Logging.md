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
