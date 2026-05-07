---
name: koreforge-settings
description: "Use when adding, fixing, or reviewing SQL-backed live-reload configuration in a KoreForge application. Covers KoreForge.Settings: AddKoreForgeSettings, AddKoreForgeSettingsServices, ISettingsService, IHistoryService, connection string resolution, hot-reload, staged rollout via ClientAppVersion, and the CLI tool."
---

# KoreForge Settings Skill

## Package

```xml
<PackageReference Include="KoreForge.Settings" />
```

## What It Provides

SQL Server-backed configuration provider that:
- Loads settings into `IConfiguration` at startup
- Hot-reloads changes every N seconds without restart
- Scopes settings per `ApplicationId`, `InstanceId`, `ClientAppVersion`
- Supports history tracking and rollback
- Encrypts values when an `IEncryptionProvider` is registered

## Registration

```csharp
// Program.cs — BEFORE any service that needs settings

// 1. Add as a configuration source (reads into IConfiguration)
builder.Configuration.AddKoreForgeSettings(opts =>
{
    opts.ApplicationId = "MyApp";
    opts.PollingInterval = TimeSpan.FromSeconds(30);  // minimum 30s
    opts.EnableMetrics = true;
    // opts.ConnectionString = "..."; // optional — see resolution order below
});

// 2. Register background service, ISettingsService, IHistoryService
builder.Services.AddKoreForgeSettingsServices(builder.Configuration);
```

## Connection String Resolution Order

Settings resolves the connection string in this priority (first wins):

1. `KoreForgeSettingsOptions.ConnectionString` (set in callback above)
2. `ConnectionStrings:KoreForgeSettings` in `appsettings.json`
3. `KF:Settings:ConnectionString` in configuration
4. `KF_SETTINGS_CONNECTIONSTRING` environment variable

## Using ISettingsService for CRUD

```csharp
// Inject and use for manual settings management
public sealed class SettingsEndpoints
{
    public static void Map(WebApplication app)
    {
        app.MapGet("/settings", async (ISettingsService svc, KoreForgeSettingsOptions opts, CancellationToken ct) =>
        {
            var rows = await svc.QueryAsync(new SettingQuery { ApplicationId = opts.ApplicationId }, ct);
            return rows;
        });

        app.MapPost("/settings", async (SettingUpsert request, ISettingsService svc, CancellationToken ct) =>
        {
            var row = await svc.UpsertAsync(request with { ChangedBy = "api" }, ct);
            return Results.Created($"/settings/{row.Id}", row);
        });
    }
}
```

## Key Interfaces

```csharp
public interface ISettingsService
{
    Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct);
    Task<SettingRow?> GetAsync(long id, CancellationToken ct);
    Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct);
    Task DeleteAsync(long id, string changedBy, byte[] expectedRowVersion, CancellationToken ct);
}

public interface IHistoryService
{
    Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct);
    Task RollbackAsync(string key, int versionIndex, string changedBy, CancellationToken ct);
}
```

## Configuration Options Reference

| Property | Default | Description |
|----------|---------|-------------|
| `ApplicationId` | `null` | Scope filter — set for every app |
| `PollingInterval` | `60s` | Hot-reload frequency (min 30s) |
| `InstanceId` | `null` | Optional per-instance scope |
| `ClientAppVersion` | `null` | For staged rollouts — see below |
| `FailFastOnStartup` | `true` | Throw on startup if SQL unreachable |
| `EnableDecryption` | `false` | Requires `IEncryptionProvider` registered |
| `EnableMetrics` | `true` | In-memory reload metrics |
| `EnableDetailedLogging` | `false` | Verbose reload traces |

## Staged Rollout — ClientAppVersion

When deploying a new binary version alongside the old, set `ClientAppVersion` so each binary reads its own setting overrides:

```csharp
builder.Configuration.AddKoreForgeSettings(opts =>
{
    opts.ApplicationId = "MyApp";
    opts.ClientAppVersion = "v2.0.0"; // new binary only; null/omit for old binary
});
```

Resolution precedence (first match per key wins):

| Level | Scope |
|-------|-------|
| 1 | (app, instance, clientVersion) |
| 2 | (app, null, clientVersion) |
| 3 | (app, instance, null) |
| 4 | (app, null, null) |
| 5 | (null, null, null) — global |

## Health Check

```csharp
app.MapGet("/health/settings", (IHealthReporter health) =>
    new { health.LastSuccessfulReloadUtc, health.ConsecutiveFailures, health.LastRowCount });
```

## CLI Tool

```bash
dotnet tool install -g KoreForge.Settings.Cli

# List all settings for an application
koreforge-settings list --application MyApp --connection "Server=...;Database=...;"

# Set a value
koreforge-settings set --application MyApp --key "Feature:Enabled" --value "true"

# View history for a key
koreforge-settings history --application MyApp --key "Feature:Enabled"

# Rollback to a previous version
koreforge-settings rollback --application MyApp --key "Feature:Enabled" --version 2

# Export / import
koreforge-settings export --application MyApp > settings.json
koreforge-settings import --application MyApp < settings.json
```

## appsettings.json Example

```json
{
  "ConnectionStrings": {
    "KoreForgeSettings": "Server=localhost,14334;Database=StreamingPlatform;User Id=sa;Password=...;TrustServerCertificate=True"
  }
}
```

## Checklist

- [ ] `KoreForge.Settings` in `Directory.Packages.props` + `.csproj`
- [ ] `AddKoreForgeSettings()` called **before** any service that reads `IConfiguration`
- [ ] `AddKoreForgeSettingsServices()` called after `AddKoreForgeSettings()`
- [ ] `ApplicationId` set — never leave it null in production
- [ ] `ConnectionStrings:KoreForgeSettings` set in appsettings (or environment variable)
- [ ] `FailFastOnStartup = true` (default) — never suppress this unless you have a fallback
