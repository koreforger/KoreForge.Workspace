# KoreForge.Data — API Reference

> Package: `KoreForge.Data` · Assembly: `KF.Data`

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

EF Core `DbContext` with scaffolded entities. Extend via partial class in `src/KF.Data/AlertsDbContext.cs`.

### Entity Sets

| DbSet | Entity Type | Namespace |
|-------|------------|-----------|
| `NotificationOutboxes` | `NotificationOutbox` | `KF.Data.Alerts.Notification` |
| `EmailPayloads` | `EmailPayload` | `KF.Data.Alerts.Notification` |
| `SmsPayloads` | `SmsPayload` | `KF.Data.Alerts.Notification` |
| `Channels` | `Channel` | `KF.Data.Alerts.Notification` |
| `Priorities` | `Priority` | `KF.Data.Alerts.Notification` |
| `OutboxStatuses` | `OutboxStatus` | `KF.Data.Alerts.Notification` |
| `SendOutcomes` | `SendOutcome` | `KF.Data.Alerts.Notification` |

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

Generated code lives in `src/KF.Data/Generated/` — do not edit.

