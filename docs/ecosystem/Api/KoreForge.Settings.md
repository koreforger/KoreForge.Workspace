# KoreForge.Settings — API Reference

> Package: `KoreForge.Settings` · Assemblies: `KoreForge.Settings`, `KoreForge.Settings.Abstractions`, `KoreForge.Settings.Core`, `KoreForge.Settings.Data`, `KoreForge.Settings.Encryption`, `KoreForge.Settings.Metrics`, `KoreForge.Settings.Cli`

## Registration

```csharp
// Configuration source
builder.Configuration.AddKoreForgeSettings(Action<KoreForgeSettingsOptions> configure)

// DI services
builder.Services.AddKoreForgeSettingsServices(IConfiguration configuration)
```

## `KoreForgeSettingsOptions`

```csharp
public sealed class KoreForgeSettingsOptions
{
    public string ConnectionString { get; set; }
    public string? ApplicationId { get; set; }
    public string? InstanceId { get; set; }
    public TimeSpan PollingInterval { get; set; } = TimeSpan.FromSeconds(60);
    public BinaryEncoding BinaryEncoding { get; set; } = BinaryEncoding.Base64Url;
    public bool FailFastOnStartup { get; set; } = true;
    public bool EnableDecryption { get; set; }
    public bool EnableMetrics { get; set; } = true;
    public bool EnableDetailedLogging { get; set; }
}
```

## `ISettingsService`

```csharp
public interface ISettingsService
{
    Task<IReadOnlyList<SettingRow>> QueryAsync(SettingQuery filter, CancellationToken ct);
    Task<SettingRow?> GetAsync(long id, CancellationToken ct);
    Task<SettingRow> UpsertAsync(SettingUpsert request, CancellationToken ct);
    Task DeleteAsync(long id, string changedBy, byte[] expectedRowVersion, CancellationToken ct);
}
```

## `IHistoryService`

```csharp
public interface IHistoryService
{
    Task<IReadOnlyList<SettingsHistoryRow>> GetHistoryAsync(long settingId, CancellationToken ct);
    Task RollbackAsync(string key, int versionIndex, string changedBy, CancellationToken ct);
}
```

## `IEncryptionProvider`

```csharp
public interface IEncryptionProvider
{
    string Encrypt(string plainText);
    string Decrypt(string cipherText);
}
```

Default: `NoOpEncryptionProvider` (pass-through). Register custom implementation when `EnableDecryption = true`.

## `IBinarySettingsAccessor`

```csharp
public interface IBinarySettingsAccessor
{
    Task<byte[]?> GetBinaryAsync(string key, CancellationToken ct);
    Task SetBinaryAsync(string key, byte[] data, string changedBy, CancellationToken ct);
}
```

## `IHealthReporter`

```csharp
public interface IHealthReporter
{
    DateTimeOffset? LastSuccessfulReloadUtc { get; }
    int ConsecutiveFailures { get; }
    int LastRowCount { get; }
}
```

## Connection String Resolution

1. `KoreForgeSettingsOptions.ConnectionString`
2. `ConnectionStrings:KoreForgeSettings`
3. `KF:Settings:ConnectionString`
4. `KF_SETTINGS_CONNECTIONSTRING` environment variable

## CLI Tool

```
koreforge-settings list|get|set|delete|history|rollback|export|import
  --application <id>
  --connection <connstr>
  --key <key>
  --value <value>
  --version <int>
```
