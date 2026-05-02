# KoreForge.Settings

| | |
|---|---|
| **Package** | `KoreForge.Settings` (meta), `KoreForge.Settings`, `KoreForge.Settings.Abstractions`, `KoreForge.Settings.Core`, `KoreForge.Settings.Data`, `KoreForge.Settings.Encryption`, `KoreForge.Settings.Metrics`, `KoreForge.Settings.Cli` |
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
builder.Configuration.AddKoreForgeSettings(opts =>
{
    opts.ApplicationId = "my-app";
    opts.PollingInterval = TimeSpan.FromSeconds(30);
    opts.EnableMetrics = true;
});

// 2. Register services
builder.Services.AddKoreForgeSettingsServices(builder.Configuration);
```

## Connection String Resolution

The connection string is resolved in priority order:

1. `KoreForgeSettingsOptions.ConnectionString` — set directly in code
2. `ConnectionStrings:KoreForgeSettings` — from `appsettings.json`
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

## CLI Tool — `koreforge-settings`

```bash
koreforge-settings list     --application my-app --connection "Server=...;Database=...;"
koreforge-settings get      --application my-app --key "Feature:Enabled"
koreforge-settings set      --application my-app --key "Feature:Enabled" --value "true"
koreforge-settings delete   --application my-app --key "Feature:Enabled"
koreforge-settings history  --application my-app --key "Feature:Enabled"
koreforge-settings rollback --application my-app --key "Feature:Enabled" --version 2
koreforge-settings export   --application my-app > settings.json
koreforge-settings import   --application my-app < settings.json
```

## Sub-Packages

| Package | Description |
|---|---|
| `KoreForge.Settings` | Configuration provider, hot-reload background service |
| `KoreForge.Settings.Abstractions` | Models, interfaces, options |
| `KoreForge.Settings.Core` | `SettingsService`, `HistoryService`, binary accessor |
| `KoreForge.Settings.Data` | EF Core `KoreForgeSettingsDbContext` |
| `KoreForge.Settings.Encryption` | `IEncryptionProvider` contract + `NoOpEncryptionProvider` |
| `KoreForge.Settings.Metrics` | In-memory metrics recorder for reload operations |
| `KoreForge.Settings.Cli` | CLI tool |

## See Also

- `KoreForge.Settings/README.md` — Full README with additional examples
