---
name: koreforge-applifecycle
description: "Use when adding, fixing, or reviewing startup flows, shutdown flows, scheduled flows, or lifecycle event hooks in a KoreForge application. Covers KoreForge.AppLifecycle: AddApplicationLifecycleManager, UseApplicationLifecycleManager, IFlowStep<TContext>, IScheduleTrigger, and lifecycle events."
---

# KoreForge AppLifecycle Skill

## Package

```xml
<PackageReference Include="KoreForge.AppLifecycle" />
```

## Core Concepts

| Concept | Description |
|---------|-------------|
| `IFlowStep<TContext>` | A single step in a flow — implement this for every action |
| `StartupContext` | Context passed to startup flow steps |
| `ShutdownContext` | Context passed to shutdown flow steps |
| `ScheduledContext` | Context for scheduled flow steps — includes `FlowName`, scheduled time |
| `IScheduleTrigger` | Implement to control the delay between scheduled runs |
| `FlowOutcome` | Return value from a step: `FlowOutcome.Success`, `FlowOutcome.Failure`, `FlowOutcome.Custom("name")` |

## Registration

```csharp
// Program.cs

// 1. Register steps and triggers as transient
builder.Services.AddTransient<BootstrapStep>();
builder.Services.AddTransient<DrainStep>();
builder.Services.AddTransient<HeartbeatStep>();
builder.Services.AddTransient<EveryMinuteTrigger>();

// 2. Configure the lifecycle manager
builder.Services.AddApplicationLifecycleManager(options =>
{
    // Startup flow — runs once before requests are accepted
    options.Startup
        .Flow("Bootstrap")
        .BeginWith<BootstrapStep>()
        .EndFlow();

    // Shutdown flow — runs once when host receives shutdown signal
    options.Shutdown
        .Flow("Drain")
        .BeginWith<DrainStep>()
        .EndFlow();

    // Scheduled flow — runs on cadence from IScheduleTrigger
    options.Scheduled
        .Flow("Heartbeat")
        .OnSchedule<EveryMinuteTrigger>()
        .NoOverlap()          // skip this run if previous is still running
        .BeginWith<HeartbeatStep>()
        .EndFlow();
});

// 3. Add the middleware FIRST in the pipeline — before auth, before controllers
var app = builder.Build();
app.UseApplicationLifecycleManager();
app.UseAuthentication();
app.UseAuthorization();
// ...
```

## Implementing Steps

```csharp
// Startup step
internal sealed class BootstrapStep : IFlowStep<StartupContext>
{
    // Inject DI services normally
    private readonly IConfiguration _config;

    public BootstrapStep(IConfiguration config) => _config = config;

    public Task<FlowOutcome> ExecuteAsync(StartupContext context, CancellationToken cancellationToken)
    {
        // Do startup work here
        return Task.FromResult(FlowOutcome.Success);
    }
}

// Shutdown step
internal sealed class DrainStep : IFlowStep<ShutdownContext>
{
    public Task<FlowOutcome> ExecuteAsync(ShutdownContext context, CancellationToken cancellationToken)
    {
        // Flush, close connections, etc.
        return Task.FromResult(FlowOutcome.Success);
    }
}

// Scheduled step
internal sealed class HeartbeatStep : IFlowStep<ScheduledContext>
{
    public Task<FlowOutcome> ExecuteAsync(ScheduledContext context, CancellationToken cancellationToken)
    {
        // Runs on cadence
        return Task.FromResult(FlowOutcome.Success);
    }
}
```

## Implementing a Trigger

```csharp
internal sealed class EveryMinuteTrigger : IScheduleTrigger
{
    public Task<TimeSpan> GetNextDelayAsync(ScheduledContext context, CancellationToken cancellationToken)
        => Task.FromResult(TimeSpan.FromMinutes(1));
}
```

## Branching Flows

```csharp
options.Startup
    .Flow("Bootstrap")
    .BeginWith<LoadConfigStep>()
    .If(FlowOutcome.Success).Then<WarmCacheStep>()
    .If(FlowOutcome.Custom("skip-cache")).Then<SkipCacheStep>()
    .EndFlow();
```

Omitting `If(...)` before `Then<>()` treats that transition as the default success path.

## Lifecycle Events

```csharp
options.Events.Configure(events =>
{
    events.StartupStepExecuted += args =>
    {
        Console.WriteLine($"[{args.Section}] {args.FlowName}:{args.StepType.Name} => {args.Outcome}");
        return Task.CompletedTask;
    };
});
```

Available events: `StartupStepExecuted`, `ShutdownStepExecuted`, startup/shutdown flow begin/end events.
Handlers are awaited sequentially; exceptions are swallowed and logged.

## Behavior Flags

Set on `ApplicationLifecycleOptions`:

| Flag | Default | Meaning |
|------|---------|---------|
| `FailFastOnStartupFailure` | `true` | Host aborts if a startup flow returns Failure |
| `FailFastOnShutdownFailure` | `false` | |
| `UnmappedOutcomePolicy` | `StopFlow` | `StopFlow`, `TreatAsFailure`, `Throw` |
| `LogUnmappedOutcomes` | `true` | Logs transitions that stop unexpectedly |

## Combined with KoreForge.Logging and Metrics

```csharp
internal sealed class BootstrapStep : IFlowStep<StartupContext>
{
    private readonly StartupLogger<BootstrapStep> _logger;
    private readonly IOperationMonitor _monitor;

    public BootstrapStep(StartupLogger<BootstrapStep> logger, IOperationMonitor monitor)
    {
        _logger = logger;
        _monitor = monitor;
    }

    public Task<FlowOutcome> ExecuteAsync(StartupContext context, CancellationToken cancellationToken)
    {
        using var scope = _monitor.Begin("MyApp.Bootstrap");
        _logger.Bootstrap.Complete.LogInformation("Bootstrap complete.");
        return Task.FromResult(FlowOutcome.Success);
    }
}
```

## Checklist

- [ ] `KoreForge.AppLifecycle` in `Directory.Packages.props` + `.csproj`
- [ ] All steps and triggers registered as `AddTransient<>()` — not singleton
- [ ] `UseApplicationLifecycleManager()` called **before** `UseAuthentication()` and `UseAuthorization()`
- [ ] `AddApplicationLifecycleManager()` called **before** `builder.Build()`
- [ ] Every flow has a unique non-empty name
- [ ] Each flow starts with `BeginWith<TStep>()` and ends with `EndFlow()`
- [ ] Scheduled flows that must not overlap call `NoOverlap()`
