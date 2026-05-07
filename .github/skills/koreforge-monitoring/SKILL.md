---
name: koreforge-monitoring
description: "Use when integrating a KoreForge application with the KoreForge Monitoring Shell (heartbeat registry, status reporting, monitoring UI protocol). Covers KoreForge.Monitoring.Contracts, KoreForge.Monitoring.Registry, KoreForge.Monitoring.AspNetCore. Keywords: heartbeat, monitoring shell, SignalR, IMonitoringRegistration, status feed."
---

# KoreForge Monitoring Skill

## Packages

```xml
<!-- Shared protocol types — add to any app that reports status -->
<PackageReference Include="KoreForge.Monitoring.Contracts" />

<!-- Heartbeat registry — add to ASP.NET apps that register with the shell -->
<PackageReference Include="KoreForge.Monitoring.Registry" />

<!-- ASP.NET endpoints + SignalR for the monitoring UI shell itself -->
<PackageReference Include="KoreForge.Monitoring.AspNetCore" />
```

## Roles

| Package | Who adds it |
|---------|-------------|
| `Contracts` | Any app sending or receiving monitoring data |
| `Registry` | An app that broadcasts its own health to the monitoring shell |
| `AspNetCore` | The monitoring shell app that aggregates and displays |

## Registering an App for Heartbeats

```csharp
// In the monitored application — typically Event.ApiHost, Event.Processor, etc.
builder.Services.AddMonitoringRegistry(options =>
{
    options.ApplicationId   = "Event.ApiHost";
    options.DisplayName     = "API Host";
    options.HeartbeatUri    = new Uri("https://monitoring.internal/hub");
    options.IntervalSeconds = 10;
});

app.UseMonitoringRegistry();   // starts the heartbeat background service
```

The registry service sends heartbeats to the monitoring hub via SignalR.

## Contracts

`KoreForge.Monitoring.Contracts` defines the protocol types shared between the monitored app and the shell:

```csharp
// Sent with each heartbeat
public sealed class AppHeartbeat
{
    public string ApplicationId { get; init; } = "";
    public string DisplayName   { get; init; } = "";
    public DateTimeOffset Timestamp { get; init; }
    public AppHealthStatus Status  { get; init; }  // Healthy, Degraded, Unhealthy
    public IReadOnlyList<ComponentStatus> Components { get; init; } = [];
}

// Per-component status within a heartbeat
public sealed class ComponentStatus
{
    public string Name    { get; init; } = "";
    public AppHealthStatus Status { get; init; }
    public string? Description { get; init; }
}

public enum AppHealthStatus { Healthy, Degraded, Unhealthy }
```

## Populating Component Status

Implement `IHeartbeatProvider` to inject custom component statuses into the heartbeat:

```csharp
public sealed class KafkaHealthProvider : IHeartbeatProvider
{
    private readonly IKafkaAdminClient _admin;

    public KafkaHealthProvider(IKafkaAdminClient admin) => _admin = admin;

    public async Task<IEnumerable<ComponentStatus>> GetStatusAsync(CancellationToken ct)
    {
        try
        {
            var meta = await _admin.GetTopicMetadataAsync("events", ct);
            return [new ComponentStatus { Name = "Kafka", Status = AppHealthStatus.Healthy }];
        }
        catch
        {
            return [new ComponentStatus
            {
                Name   = "Kafka",
                Status = AppHealthStatus.Unhealthy,
                Description = "Failed to reach broker"
            }];
        }
    }
}

// Register
builder.Services.AddScoped<IHeartbeatProvider, KafkaHealthProvider>();
```

Multiple `IHeartbeatProvider` implementations can be registered — all are called and merged.

## Monitoring Shell Setup (AspNetCore)

This is for the dedicated monitoring shell app (`KoreForge.Monitoring.Shell`), not individual apps:

```csharp
builder.Services.AddMonitoringShell(options =>
{
    options.RetentionPeriod = TimeSpan.FromMinutes(5); // how long to keep last heartbeat
});

app.MapMonitoringShellHub();   // SignalR hub at /monitoring-hub
app.MapMonitoringShellApi();   // REST feed at /monitoring/apps
```

The shell app aggregates heartbeats from all registered applications.

## Security Note

- The monitoring shell hub (`/monitoring-hub`) should be secured behind internal network or JWT
- Individual app heartbeat endpoints only transmit to the configured hub URL — no inbound exposure
- Monitoring data is **read-only V1** — there are no mutations through the shell protocol

## Checklist

For a monitored application:
- [ ] `KoreForge.Monitoring.Contracts` + `KoreForge.Monitoring.Registry` in `Directory.Packages.props` + `.csproj`
- [ ] `AddMonitoringRegistry(opts => { opts.ApplicationId = "..."; opts.HeartbeatUri = ...; })`
- [ ] `app.UseMonitoringRegistry()` called in pipeline
- [ ] `IHeartbeatProvider` implementations registered for each dependency to surface

For the monitoring shell:
- [ ] `KoreForge.Monitoring.AspNetCore` in `.csproj`
- [ ] `AddMonitoringShell()` + `app.MapMonitoringShellHub()` + `app.MapMonitoringShellApi()`
- [ ] Hub endpoint secured (auth middleware before hub mapping)
