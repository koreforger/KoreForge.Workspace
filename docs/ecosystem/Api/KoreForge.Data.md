# KoreForge.Data — API Reference

> Package: `KoreForge.Data` · Assembly: `KoreForge.Data`

## Registration

```csharp
// Scoped DbContext
services.AddAlertsDb(Action<AlertsDbOptions> configure)
services.AddAlertsDb(string connectionString)

// Factory pattern
services.AddAlertsDbFactory(Action<AlertsDbOptions> configure)
services.AddAlertsDbFactory(string connectionString)
```

## `AlertsDbOptions`

```csharp
public sealed class AlertsDbOptions
{
    public const string SectionName = "AlertsDb";
    public string ConnectionString { get; set; } = string.Empty;
}
```

## `AlertsDbContext`

EF Core `DbContext` with scaffolded entities. Extend via partial class in `src/KoreForge.Data/AlertsDbContext.cs`.

### Entity Sets

| DbSet | Entity Type | Namespace |
|-------|------------|-----------|
| `NotificationOutboxes` | `NotificationOutbox` | `KoreForge.Data.Alerts.Notification` |
| `EmailPayloads` | `EmailPayload` | `KoreForge.Data.Alerts.Notification` |
| `SmsPayloads` | `SmsPayload` | `KoreForge.Data.Alerts.Notification` |
| `Channels` | `Channel` | `KoreForge.Data.Alerts.Notification` |
| `Priorities` | `Priority` | `KoreForge.Data.Alerts.Notification` |
| `OutboxStatuses` | `OutboxStatus` | `KoreForge.Data.Alerts.Notification` |
| `SendOutcomes` | `SendOutcome` | `KoreForge.Data.Alerts.Notification` |

### `NotificationOutbox`

Core entity with foreign keys to all lookup tables, retry tracking, and timestamps.

### Lookup Entities

`Channel`, `Priority`, `OutboxStatus`, `SendOutcome` — simple id + name pairs.

### Payload Entities

- `EmailPayload` — FromAddress, CcRecipients, BccRecipients, IsHtml
- `SmsPayload` — FromNumber, ProviderMessageId

## Scaffolding

```powershell
.\scr\scaffold.ps1
```

Generated code lives in `src/KoreForge.Data/Generated/` — do not edit.

