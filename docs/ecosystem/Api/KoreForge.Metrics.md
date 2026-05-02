# KoreForge.Metrics — API Reference

**Package**: `KoreForge.Metrics`  |  **Assembly**: `KoreForge.Metrics.dll`  |  **Namespace**: `KoreForge.Metrics`

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
