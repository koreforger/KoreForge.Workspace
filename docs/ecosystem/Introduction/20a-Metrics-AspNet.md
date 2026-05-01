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
