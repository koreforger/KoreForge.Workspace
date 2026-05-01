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
