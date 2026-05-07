---
name: koreforge-metrics
description: "Use when adding, fixing, or reviewing operation metrics/instrumentation in any KoreForge application. Covers KoreForge.Metrics (IOperationMonitor, OperationScope, OperationTags, IOperationEventSink) and KoreForge.Metrics.AspNet (MapMonitoringEndpoints, MonitoringControllerBase). Keywords: IOperationMonitor, OperationScope, MarkFailed, OperationTags, MonitoringSnapshot."
---

# KoreForge Metrics Skill

## Packages

```xml
<!-- Core metrics engine — always required -->
<PackageReference Include="KoreForge.Metrics" />

<!-- ASP.NET endpoint exposure — add when you need /monitoring/snapshot -->
<PackageReference Include="KoreForge.Metrics.AspNet" />
```

## Step 1 — Register Services

```csharp
// Program.cs
builder.Services.AddKoreForgeMetrics();

// With options (all optional — defaults are fine for most apps):
builder.Services.AddKoreForgeMetrics(options =>
{
    options.TimeMode = MonitoringTimeMode.Utc;       // default
    options.SamplingRate = 1;                        // every operation
    options.EnableCpuMeasurement = false;            // default; enable only for profiling
});
```

`AddKoreForgeMetrics` registers:
- `IOperationMonitor` (singleton) — the instrumentation entry point
- `IMonitoringSnapshotProvider` (singleton) — for diagnostics endpoints
- `IMonitoringDataSource` (singleton) — for advanced polling

## Step 2 — Expose the Snapshot Endpoint

```csharp
// Minimal API (simplest — no auth on this endpoint by convention):
app.MapMonitoringEndpoints();

// Or use the controller base if you need auth or custom routing:
[Route("api/monitoring")]
public sealed class MonitoringController : MonitoringControllerBase
{
    public MonitoringController(IMonitoringSnapshotProvider snapshots) : base(snapshots) { }

    [HttpGet("snapshot")]
    public ActionResult<MonitoringSnapshot> Get() => GetSnapshotCore();
}
```

`GET /monitoring/snapshot` returns `MonitoringSnapshot` — no auth required in the default wiring.

## Step 3 — Instrument Code

```csharp
public sealed class CheckoutService
{
    private readonly IOperationMonitor _monitor;

    public CheckoutService(IOperationMonitor monitor)
    {
        _monitor = monitor;
    }

    public async Task PlaceOrderAsync(Order order)
    {
        // Name the operation — use dot-separated hierarchy: "Area.Component.Operation"
        using var scope = _monitor.Begin("Checkout.PlaceOrder",
            new OperationTags(new Dictionary<string, string>
            {
                ["region"]  = order.Region,
                ["channel"] = order.Channel
            }));

        try
        {
            await _processor.RunAsync(order);
        }
        catch
        {
            scope.MarkFailed();
            throw;
        }
    }
}
```

### OperationTags

`OperationTags` requires a `Dictionary<string, string>` in the constructor — the indexer setter is **read-only**:

```csharp
// CORRECT
new OperationTags(new Dictionary<string, string> { ["key"] = "value" })

// WRONG — indexer is read-only
var tags = new OperationTags();
tags["key"] = "value";
```

### Scope Lifecycle

- Call `scope.MarkFailed()` **before** `Dispose` (i.e. before the `using` block exits) to record a failure
- Disposing the scope is sufficient for success — no extra call needed
- 4xx/5xx HTTP responses = `scope.MarkFailed()` in middleware

### Operation Name Convention

Use dot-separated hierarchical names scoped to the application:
```
ApiHost.Auth.ServiceApiKey
ApiHost.Authorization.PolicyEvaluate
ApiHost.Bootstrap
ApiHost.Request.<PolicyName>
Checkout.PlaceOrder
```

## Step 4 — React to Slow Operations (Optional)

Implement `IOperationEventSink` and register it in DI:

```csharp
public sealed class AlertingSink : IOperationEventSink
{
    private readonly ILogger<AlertingSink> _logger;

    public AlertingSink(ILogger<AlertingSink> logger) => _logger = logger;

    public void OnOperationCompleted(OperationCompletedContext context)
    {
        if (context.Duration > TimeSpan.FromSeconds(1))
            _logger.LogWarning("Slow {Operation} ({Duration} ms)",
                context.Name, context.Duration.TotalMilliseconds);
    }
}

// Register — the engine injects IEnumerable<IOperationEventSink> automatically
builder.Services.AddSingleton<IOperationEventSink, AlertingSink>();
```

## MonitoringSnapshot Shape

`GET /monitoring/snapshot` returns:

```json
{
  "operations": [
    {
      "name": "ApiHost.Request.CashoutOrchestrator.V1.GetOrders",
      "totalCount": 1200,
      "totalFailures": 3,
      "currentInFlight": 2,
      "peakInFlight": 14,
      "currentRatePerSecond": 4.2,
      "currentAverageDuration": "00:00:00.023",
      "currentMaxDuration": "00:00:00.410",
      "perMinute": [...],
      "perHour": [...]
    }
  ]
}
```

`perMinute` and `perHour` are rolling circular-buffer arrays (~60 minutes, ~24 hours).

## Configuration Reference

| Option | Default | Notes |
|--------|---------|-------|
| `TimeMode` | `Utc` | `Local` for server-local timestamps |
| `SamplingRate` | `1` | N = sample 1-in-N calls |
| `MaxOperationCount` | `500` | Cap on distinct operation names |
| `EventDispatchMode` | `BackgroundQueue` | `Inline` for very low-volume scenarios |
| `EventQueueCapacity` | `8192` | Bounded queue; `DroppedEvents` counter on overflow |
| `EnableCpuMeasurement` | `false` | Enable only when profiling |

## Checklist

- [ ] `KoreForge.Metrics` (+ `KoreForge.Metrics.AspNet` if exposing snapshot endpoint)
- [ ] `AddKoreForgeMetrics()` in DI setup
- [ ] `app.MapMonitoringEndpoints()` (or controller variant) in pipeline
- [ ] All instrumented methods inject `IOperationMonitor` via constructor
- [ ] Every `Begin()` scope wrapped in `using` — never dispose manually
- [ ] `scope.MarkFailed()` called before `catch` block rethrows or on explicit failure paths
- [ ] `OperationTags` constructed with `new OperationTags(new Dictionary<string, string> { ... })`
