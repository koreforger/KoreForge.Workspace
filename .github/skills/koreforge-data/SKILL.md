---
name: koreforge-data
description: "Use when scaffolding, querying, extending, or testing EF Core database contexts in a KoreForge application. Covers KoreForge.Data: scaffold-db.ps1, scaffold-config.json, Generated/ rules, partial class extensions, AddAlertsDb, lookup table patterns, SQLite in-memory tests."
---

# KoreForge Data Skill

## Package

```xml
<PackageReference Include="KoreForge.Data" />
```

## Core Rules

1. **Never edit files in `Generated/` folders** — they are overwritten by `scaffold-db.ps1`
2. **Extend via partial classes at the project root** — outside `Generated/`
3. **Lookup data lives in database tables** — no C# enums for reference/status data
4. **Use `scaffold-db.ps1`** — never run raw `dotnet ef dbcontext scaffold` directly
5. **Tests use SQLite in-memory** — no SQL Server dependency for unit tests

## Registration

```csharp
// Program.cs
builder.Services.AddAlertsDb(opts =>
    opts.ConnectionString = builder.Configuration.GetConnectionString("AlertsDB")!);

// With options for replica read scaling:
builder.Services.AddAlertsDb(opts =>
{
    opts.ConnectionString = builder.Configuration.GetConnectionString("AlertsDB")!;
    opts.ReadReplicaConnectionString = builder.Configuration.GetConnectionString("AlertsDB-ReadReplica");
});
```

## Entity Namespaces

- Contexts, options, DI extensions: `KoreForge.Data`
- Entities (Alerts DB, Notification schema): `KoreForge.Data.Alerts.Notification`
- "Generated" never appears in a namespace — it's a folder convention only

## Querying

```csharp
// Simple collection
var channels = await db.Channel.ToListAsync(ct);

// With navigations — always include before accessing
var pending = await db.NotificationOutbox
    .Include(n => n.Channel)
    .Include(n => n.Priority)
    .Include(n => n.OutboxStatus)
    .Where(n => n.OutboxStatus.Name == "Pending")
    .ToListAsync(ct);
```

## Lookup Tables Pattern

Reference data (statuses, channels, priorities) lives in the database:

```csharp
// Lookup by name — not by integer ID
var emailChannel = await db.Channel.SingleAsync(c => c.Name == "Email", ct);

// Navigate via FK — always include the navigation
var notification = await db.NotificationOutbox
    .Include(n => n.Channel)
    .FirstAsync(n => n.OutboxStatus.Name == "Pending", ct);

Console.WriteLine(notification.Channel.Name);  // "Email"
```

## Extending Generated Entities

Add computed properties or helper methods using partial classes **at the project root**:

```csharp
// src/KoreForge.Data/NotificationOutboxExtensions.cs
namespace KoreForge.Data.Alerts.Notification;

public partial class NotificationOutbox
{
    public bool IsOverdue =>
        OutboxStatus?.Name == "Pending" &&
        CreatedAt < DateTimeOffset.UtcNow.AddHours(-1);
}
```

## Extending the DbContext

Use the empty partial at `src/KoreForge.Data/AlertsDbContext.cs`:

```csharp
namespace KoreForge.Data;

public partial class AlertsDbContext
{
    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        // Extra fluent API config — indexes, value conversions, etc.
    }
}
```

## Scaffolding Workflow

### When the Schema Changes

```powershell
# Apply DDL to the database first, then:
.\scr\scaffold-db.ps1

# For a specific database:
.\scr\scaffold-db.ps1 -Database AlertsDB
```

Review changes in `Generated/` — then update tests for any new entities.

### scaffold-config.json — Adding a New Database

```json
{
  "name": "OrdersDB",
  "connectionString": "Server=localhost,1433;Database=Orders;User Id=sa;Password=...;TrustServerCertificate=True",
  "provider": "Microsoft.EntityFrameworkCore.SqlServer",
  "context": "OrdersDbContext",
  "outputDir": "src/KoreForge.Data/Generated/Orders/Dbo",
  "contextDir": "src/KoreForge.Data/Generated/Orders",
  "namespace": "KoreForge.Data.Orders",
  "contextNamespace": "KoreForge.Data",
  "schemas": ["dbo"],
  "tables": ["dbo.Order", "dbo.OrderLine"],
  "useDatabaseNames": true,
  "noOnConfiguring": true
}
```

After scaffolding a new database, add manually:
- `src/KoreForge.Data/NewDbOptions.cs` — connection string holder
- `src/KoreForge.Data/NewDbServiceCollectionExtensions.cs` — `AddNewDb(opts => ...)` extension
- `src/KoreForge.Data/NewDbContext.cs` — empty partial for extensions

## Unit Testing with SQLite

```csharp
public static AlertsDbContext CreateInMemory()
{
    var options = new DbContextOptionsBuilder<AlertsDbContext>()
        .UseSqlite("DataSource=:memory:")
        .Options;

    var db = new AlertsDbContext(options);
    db.Database.EnsureCreated();
    return db;
}

[Fact]
public async Task Channel_Insert_And_Query()
{
    await using var db = CreateInMemory();
    db.Channel.Add(new Channel { Name = "Email" });
    await db.SaveChangesAsync();

    var result = await db.Channel.SingleAsync(c => c.Name == "Email");
    Assert.Equal("Email", result.Name);
}
```

## Checklist

- [ ] `KoreForge.Data` in `Directory.Packages.props` + `.csproj`
- [ ] `AddAlertsDb(opts => opts.ConnectionString = ...)` in DI setup
- [ ] Connection string in `appsettings.json` under `ConnectionStrings:AlertsDB`
- [ ] All entity extensions go in partial classes at project root — never in `Generated/`
- [ ] No C# enums for reference data — query lookup tables by `Name`
- [ ] Tests use SQLite in-memory — no SQL Server needed for unit tests
- [ ] Schema changes → run `scaffold-db.ps1` → review `Generated/` diff
