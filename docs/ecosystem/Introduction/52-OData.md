# KoreForge.OData

| | |
|---|---|
| **Package** | `KoreForge.OData`, `KoreForge.OData.Generators` |
| **Namespace** | `KoreForge.OData`, `KoreForge.OData.Generators` |
| **Source** | `KoreForge.OData/src/` |
| **Tests** | `KoreForge.OData/tst/` (unit: 21 tests, integration: 13 tests) |
| **Dependencies** | Microsoft.AspNetCore.OData, EF Core, Roslyn (generator) |

## Problem

Exposing an EF Core `DbContext` as an OData API requires writing a controller per entity, registering each entity in the EDM model, wiring up authorization per operation, and maintaining all of this as the database schema evolves. The boilerplate is proportional to the number of entities and is identical in structure — only the types change.

## Solution

KoreForge.OData provides a Roslyn source generator that inspects your `DbContext` at compile time and emits:

- One OData controller per DbSet, inheriting `KoreForgeODataController<TContext, TEntity, TKey>`
- An EDM configurator implementing `IEdmModelConfigurator`
- Schema-aware route prefixes: `/odata/{ContextPrefix}/{EntitySet}`

Security is declarative via attributes on entity classes. Row-level filtering is pluggable via DI.

## Compromises

- Source generators require `netstandard2.0` for the generator assembly. The runtime library targets `net10.0`.
- Only single-key entities are supported. Composite keys require manual controller implementation.
- The generator reads `DbSet<T>` properties — entities not exposed as DbSets are not generated.

## Installation

```xml
<PackageReference Include="KoreForge.OData" />
<PackageReference Include="KoreForge.OData.Generators"
                  OutputItemType="Analyzer"
                  ReferenceOutputAssembly="false" />
```

## DI Registration

```csharp
// Register the generated EDM configurator
builder.Services.AddEdmModelConfigurator<SalesEdmConfigurator>();

// Add controllers with OData support
builder.Services.AddControllers().AddKoreForgeOData();
```

## Usage

### 1. Annotate Entities

```csharp
[ODataAuthorize(ReadPolicy = "CanReadOrders", CreatePolicy = "CanCreateOrders")]
public class Order
{
    [Key]
    public int OrderId { get; set; }
    public string Description { get; set; } = "";

    [ODataPropertyRestriction(DenyPatch = true, DenyPut = true)]
    public string CreatedBy { get; set; } = "system";
}

[ODataIgnore]   // Excluded from OData generation
public class AuditLog { /* ... */ }
```

### 2. Build

The source generator emits controllers and EDM configurators. No code to write.

### 3. Routes

Generated routes follow the pattern:

```
/odata/{ContextPrefix}/{EntitySet}
```

For a `SalesDbContext` with a `DbSet<Order>`, the route is `/odata/Sales/Orders`.

## Attributes

| Attribute | Target | Purpose |
|-----------|--------|---------|
| `[ODataAuthorize]` | Entity class | Per-operation policies: `ReadPolicy`, `CreatePolicy`, `UpdatePolicy`, `DeletePolicy` |
| `[ODataIgnore]` | Entity class | Exclude entity from OData generation |
| `[ODataPropertyRestriction]` | Property | `DenyPatch`, `DenyPut`, `DenyRead`, `DenySerialization` |

## Security Layers

### Entity-Level Authorization

`[ODataAuthorize]` maps CRUD operations to ASP.NET Core authorization policies:

```csharp
[ODataAuthorize(
    ReadPolicy = "Reader",
    CreatePolicy = "Writer",
    UpdatePolicy = "Writer",
    DeletePolicy = "Admin")]
public class Product { ... }
```

### Property-Level Restrictions

```csharp
[ODataPropertyRestriction(DenyPatch = true, DenySerialization = true)]
public string InternalNotes { get; set; }
```

### Row-Level Filtering

Implement `IRowLevelFilterProvider<TEntity>` and register in DI:

```csharp
public class TenantOrderFilter : IRowLevelFilterProvider<Order>
{
    public IQueryable<Order> ApplyFilter(IQueryable<Order> query)
        => query.Where(o => o.TenantId == _currentTenant.Id);
}

builder.Services.AddScoped<IRowLevelFilterProvider<Order>, TenantOrderFilter>();
```

## OData Query Support

| Option | Example |
|--------|---------|
| `$filter` | `/odata/Sales/Orders?$filter=Total gt 100` |
| `$select` | `/odata/Sales/Orders?$select=OrderId,Total` |
| `$orderby` | `/odata/Sales/Orders?$orderby=Total desc` |
| `$top` / `$skip` | `/odata/Sales/Orders?$top=10&$skip=20` |
| `$count` | `/odata/Sales/Orders?$count=true` |
| `$expand` | `/odata/Sales/Orders?$expand=Items` |

## See Also

- `KoreForge.OData/doc/UsageGuide.md` — Extended usage guide
- `KoreForge.OData/doc/SecurityGuide.md` — Security configuration reference
