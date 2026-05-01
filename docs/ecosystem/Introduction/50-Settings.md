# KoreForge.Settings

| | |
|---|---|
| **Package** | `KoreForge.Settings` (meta), `KF.Settings`, `KF.Settings.Abstractions`, `KF.Settings.Core`, `KF.Settings.Data`, `KF.Settings.Encryption`, `KF.Settings.Metrics`, `KoreForge.Settings.Cli` |
| **Namespace** | `KoreForge.Settings.*` |
| **Source** | `KoreForge.Settings/src/` |
| **Tests** | `KoreForge.Settings/tst/` |
| **Dependencies** | EF Core (SQL Server), Microsoft.Extensions.Configuration |

## Problem

`appsettings.json` is baked into the deployment. Changing a setting means redeploying or manually editing files on a server. There is no audit trail, no rollback capability, and no way to change configuration at runtime across multiple instances of the same application.

Environment variables help but are difficult to manage at scale, offer no history, and cannot be queried or exported.

## Solution

KoreForge.Settings stores configuration in SQL Server with a .NET `IConfigurationProvider` that reloads automatically on a polling interval. Settings are scoped per application (and optionally per instance), support encryption for sensitive values, maintain full history with rollback, and expose health metrics. A CLI tool provides command-line management.

The configuration source is transparent to application code — `IConfiguration`, `IOptions<T>`, and `IOptionsMonitor<T>` all work as expected with hot-reload support.

## Compromises

- Requires SQL Server for storage. No pluggable backend (by design — one database, one source of truth).
- Polling-based reload, not push-based. Minimum interval is 30 seconds. Changes are not instant.
- Encryption is opt-in via `IEncryptionProvider`. The default implementation is no-op — you must provide your own encryption strategy for production secrets.

## Installation

```bash
dotnet add package KoreForge.Settings

# CLI tool (global)
dotnet tool install -g KoreForge.Settings.Cli
```

## DI Registration

```csharp
var builder = WebApplication.CreateBuilder(args);

// 1. Add KF Settings as a configuration source
builder.Configuration.AddKFSettings(opts =>
{
    opts.ApplicationId = "my-app";
    opts.PollingInterval = TimeSpan.FromSeconds(30);
    opts.EnableMetrics = true;
});

// 2. Register services
builder.Services.AddKFSettingsServices(builder.Configuration);
```

## Connection String Resolution

The connection string is resolved in priority order:

1. `KFSettingsOptions.ConnectionString` — set directly in code
2. `ConnectionStrings:KFSettings` — from `appsettings.json`
3. `KF:Settings:ConnectionString` — from configuration
4. `KF_SETTINGS_CONNECTIONSTRING` — environment variable

## Configuration Options

| Property | Default | Description |
|----------|---------|-------------|
| `ConnectionString` | _(resolved)_ | SQL Server connection string |
| `ApplicationId` | `null` | Scope filter for multi-app isolation |
| `InstanceId` | `null` | Optional instance-level scope |
| `PollingInterval` | `60s` | Background reload frequency (min 30s) |
| `BinaryEncoding` | `Base64Url` | Encoding for binary settings |
| `FailFastOnStartup` | `true` | Throw on startup validation failure |
| `EnableDecryption` | `false` | Enable value decryption (requires `IEncryptionProvider`) |
| `EnableMetrics` | `true` | In-memory metrics collection |
| `EnableDetailedLogging` | `false` | Verbose reload traces |

## API Reference

### ISettingsService

```csharp
public interface ISettingsService
{
    Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct);
    Task<SettingRow?> GetAsync(long id, CancellationToken ct);
    Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct);
    Task DeleteAsync(long id, string changedBy, byte[] expectedRowVersion, CancellationToken ct);
}
```

### IHistoryService

```csharp
public interface IHistoryService
{
    Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct);
    Task RollbackAsync(string key, int versionIndex, string changedBy, CancellationToken ct);
}
```

### Hot Reload

The `SettingsReloadBackgroundService` polls SQL Server at the configured interval. Change detection uses row count + max row version + key checksum. Updates are atomic — the configuration snapshot is rebuilt entirely before being swapped in.

Health is exposed via `IHealthReporter`:

```csharp
app.MapGet("/health/settings", (IHealthReporter health) =>
    new { health.LastSuccessfulReloadUtc, health.ConsecutiveFailures, health.LastRowCount });
```

## CLI Tool — `kf-settings`

```bash
kf-settings list     --application my-app --connection "Server=...;Database=...;"
kf-settings get      --application my-app --key "Feature:Enabled"
kf-settings set      --application my-app --key "Feature:Enabled" --value "true"
kf-settings delete   --application my-app --key "Feature:Enabled"
kf-settings history  --application my-app --key "Feature:Enabled"
kf-settings rollback --application my-app --key "Feature:Enabled" --version 2
kf-settings export   --application my-app > settings.json
kf-settings import   --application my-app < settings.json
```

## Sub-Packages

| Package | Description |
|---|---|
| `KF.Settings` | Configuration provider, hot-reload background service |
| `KF.Settings.Abstractions` | Models, interfaces, options |
| `KF.Settings.Core` | `SettingsService`, `HistoryService`, binary accessor |
| `KF.Settings.Data` | EF Core `KFSettingsDbContext` |
| `KF.Settings.Encryption` | `IEncryptionProvider` contract + `NoOpEncryptionProvider` |
| `KF.Settings.Metrics` | In-memory metrics recorder for reload operations |
| `KF.Settings.Cli` | CLI tool |

## See Also

- `KoreForge.Settings/README.md` — Full README with additional examples
