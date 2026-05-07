---
name: koreforge-logging
description: "Use when adding, fixing, or reviewing structured logging in any KoreForge application. Covers KoreForge.Logging (enum-driven source generator), KoreForge.Logging.Serilog (Serilog backend + LogStash sink), and correct DI wiring. NEVER use ILogger<T> directly — always use the generated loggers from this skill."
---

# KoreForge Logging Skill

## Critical Rule

**Never inject `ILogger<T>` into application code.** Always use KoreForge.Logging generated loggers. `ILogger<T>` and `ILoggerFactory` are framework seams used only inside `AuthenticationHandler` base classes and similar framework-owned types.

## Packages Required

```xml
<!-- Always required for structured logging -->
<PackageReference Include="KoreForge.Logging" />

<!-- Required for Serilog backend (console, LogStash) — most apps need this -->
<PackageReference Include="KoreForge.Logging.Serilog" />
```

`KoreForge.Logging.Serilog` depends on `KoreForge.Logging`, but add **both** explicitly so the source generator fires in the consuming project.

## Step 1 — Define Log Events

Create one enum per project (or one per logical area) in a `Logging/` folder, one type per file:

```csharp
using KoreForge.Logging;

namespace MyApp.Logging;

[LogEventSource(LoggerRootTypeName = "MyAppLogger", BasePath = "MyApp")]
public enum MyAppLogEvents
{
    // AREA_Group_Action = numeric id
    // Use single-concept words for each token — ToIdentifier() lowercases everything
    // except the first char. "ServiceApiKey" becomes "Serviceapikey". Use "Apikey".
    STARTUP_Bootstrap_Complete = 1000,
    STARTUP_Bootstrap_Failed   = 1001,

    AUTH_Permission_Denied   = 2000,
    AUTH_Permission_Rejected = 2001,
    AUTH_Apikey_Rejected     = 3000,
}
```

### Naming Convention

- Format: `AREA_Group_Action` — underscore-separated PascalCase tokens
- The generator splits on `_` and calls `ToIdentifier(token)` which produces PascalCase preserving only the first char uppercase
- **Action token must be a single word**: `Complete`, `Failed`, `Denied`, `Rejected` — NOT `DenyNoRule` (becomes `Denynorule`)
- Numeric values must be positive and unique (`KLG0001` error if duplicate)

### Attribute Options

| Option | Use |
|--------|-----|
| `LoggerRootTypeName` | Name of the root generated logger class, e.g. `"MyAppLogger"` |
| `BasePath` | Prefix prepended to all event paths, e.g. `"MyApp"` → `MyApp.Auth.Permission.Denied` |
| `Namespace` | Override namespace (defaults to enum's namespace) |

## Step 2 — What Gets Generated

For the enum above the generator produces:
- `MyAppLogger<T>` — root logger with `Startup` and `Auth` properties
- `StartupLogger<T>` — area logger with `Bootstrap` group property
- `StartupBootstrapLogger<T>` — group logger with `Complete` and `Failed` `IEventLogger` properties
- `AuthLogger<T>` — area logger with `Permission` and `Apikey` group properties
- `GeneratedLoggingServiceCollectionExtensions.AddGeneratedLogging()` — registers all area loggers as scoped open-generic services

**Only area-level loggers are registered in DI.** Group and sub-group loggers are accessed via properties, not injected directly.

```
Inject:   AuthLogger<MyService>         → _logger.Permission.Denied.LogWarning(...)
          StartupLogger<MyService>      → _logger.Bootstrap.Complete.LogInformation(...)
          MyAppLogger<MyService>        → _logger.Auth.Permission.Denied.LogWarning(...)
```

## Step 3 — Register in DI

```csharp
// Program.cs

// Serilog backend (replaces default MEL provider):
builder.Services.AddKFSerilogLogging();

// Generated loggers (area loggers registered as scoped open-generic):
builder.Services.AddGeneratedLogging();
```

`AddGeneratedLogging()` is the generated extension method — it lives in the same namespace as the `[LogEventSource]` enum.

### Serilog Options

```csharp
builder.Services.AddKFSerilogLogging(options =>
{
    options.MinimumLevel = LogLevel.Information;
    options.WriteToConsole = true;
    // For ELK/LogStash:
    options.LogStash = new LogStashOptions
    {
        Host = "elk.example.com",
        Port = 5044,
        UseTcp = true,
        ApplicationName = "MyApp",
        Environment = "Production"
    };
});
```

## Step 4 — Inject and Use

```csharp
// Inject the area-level logger (not the root, not ILogger<T>)
internal sealed class BootstrapStep : IFlowStep<StartupContext>
{
    private readonly StartupLogger<BootstrapStep> _logger;

    public BootstrapStep(StartupLogger<BootstrapStep> logger)
    {
        _logger = logger;
    }

    public Task<FlowOutcome> ExecuteAsync(StartupContext ctx, CancellationToken ct)
    {
        _logger.Bootstrap.Complete.LogInformation("Bootstrap complete.");
        return Task.FromResult(FlowOutcome.Success);
    }
}
```

```csharp
// For framework-owned base classes that require ILoggerFactory (e.g. AuthenticationHandler),
// inject BOTH the framework type AND the generated logger:
internal sealed class MyAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly AuthLogger<MyAuthHandler> _kfLogger;

    public MyAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory loggerFactory,   // required by base class only
        UrlEncoder encoder,
        AuthLogger<MyAuthHandler> kfLogger)
        : base(options, loggerFactory, encoder)
    {
        _kfLogger = kfLogger;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        _kfLogger.Apikey.Rejected.LogWarning("Rejected unknown API key.");
        return Task.FromResult(AuthenticateResult.Fail("Invalid API key."));
    }
}
```

## Event Metadata

Each log call automatically attaches:
- `EventId.Id` = enum numeric value
- `EventId.Name` = full event path (e.g. `MyApp.Auth.Permission.Denied`)
- Scope `EventPath = <event path>` for downstream sink enrichment

## LogStash JSON Shape

```json
{
  "@timestamp": "...",
  "level": "Warning",
  "event_id": 2000,
  "event_path": "MyApp.Auth.Permission.Denied",
  "message": "...",
  "application": "MyApp"
}
```

## Checklist

- [ ] `KoreForge.Logging` AND `KoreForge.Logging.Serilog` in `Directory.Packages.props` + `.csproj`
- [ ] One `[LogEventSource]` enum per project with `AREA_Group_Action` naming
- [ ] Single-concept action tokens (one word, no camel-case compound)
- [ ] `AddKFSerilogLogging()` called before `AddGeneratedLogging()`
- [ ] `AddGeneratedLogging()` called in DI setup
- [ ] All constructors inject area loggers (`AuthLogger<T>`, `StartupLogger<T>`), never `ILogger<T>`
