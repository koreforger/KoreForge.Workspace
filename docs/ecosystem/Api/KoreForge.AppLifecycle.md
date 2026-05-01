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
