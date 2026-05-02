# KoreForge.Metrics

| | |
|---|---|
| **Package** | `KoreForge.Metrics` |
| **Namespace** | `KoreForge.Metrics` |
| **Source** | `KoreForge.Metrics/src/KoreForge.Metrics/` |
| **Tests** | `KoreForge.Metrics/tst/KoreForge.Metrics.Tests/` |
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
