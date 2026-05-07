---
name: koreforge-odata
description: "Use when adding, fixing, or reviewing OData endpoints in a KoreForge application. Covers KoreForge.OData: source generator, AddKoreForgeOData, AddEdmModelConfigurator, ODataAuthorize, ODataPropertyRestriction, ODataIgnore, IRowLevelFilterProvider, controller hooks. Keywords: OData, DbSet, EDM, row-level filter, ODataIgnore."
---

# KoreForge OData Skill

## Packages

```xml
<!-- Runtime OData support -->
<PackageReference Include="KoreForge.OData" />

<!-- Source generator — analyzer only, no runtime dependency -->
<PackageReference Include="KoreForge.OData.Generators" OutputItemType="Analyzer" ReferenceOutputAssembly="false" />
```

## What the Generator Produces

For every non-`[ODataIgnore]` `DbSet<T>` on a `DbContext`, the generator produces:
- A controller class: `{EntityName}sController : KoreForgeODataController<TContext, TEntity, TKey>`
- An EDM configurator: `{ContextName}EdmConfigurator : IEdmModelConfigurator`

## Registration

```csharp
// Program.cs

// 1. Register the generated EDM configurator
builder.Services.AddEdmModelConfigurator<SalesEdmConfigurator>();

// 2. Add controllers with OData support
builder.Services.AddControllers().AddKoreForgeOData();
```

This exposes routes at `/odata/{ContextPrefix}/{EntitySet}`:
- `GET /odata/Sales/Products` — collection query (supports $filter, $select, $orderby, $top, $skip, $count, $expand)
- `GET /odata/Sales/Products(1)` — single entity
- `POST /odata/Sales/Orders` — create
- `PUT /odata/Sales/Orders(1)` — replace
- `PATCH /odata/Sales/Orders(1)` — partial update
- `DELETE /odata/Sales/Orders(1)` — delete

## Entity Annotations

### ODataIgnore — Exclude an Entity

```csharp
[ODataIgnore]
public class AuditLog { }   // Not exposed via OData
```

### ODataAuthorize — Authorization Policies per Operation

```csharp
[ODataAuthorize(
    ReadPolicy   = "CanReadOrders",
    CreatePolicy = "CanCreateOrders",
    UpdatePolicy = "CanUpdateOrders",
    DeletePolicy = "CanDeleteOrders")]
public class Order { ... }

// Role-based shorthand
[ODataAuthorize(ReadRoles = "Reader,Admin", CreateRoles = "Admin")]
public class Product { ... }
```

If a policy/role is not set, that operation is **allowed by default**.
Failed authorization returns `403 Forbidden` before any DB access.

### ODataPropertyRestriction — Protect Individual Properties

```csharp
public class Order
{
    [Key]
    public int OrderId { get; set; }

    // Cannot be changed after creation
    [ODataPropertyRestriction(DenyPatch = true, DenyPut = true)]
    public string CreatedBy { get; set; } = "system";

    // Never returned in queries or serialization
    [ODataPropertyRestriction(DenyRead = true, DenySerialization = true)]
    public string InternalSecret { get; set; } = "";
}
```

| Flag | Effect |
|------|--------|
| `DenyPatch` | `400` if property appears in a PATCH delta |
| `DenyPut` | `400` if value differs from existing value in a PUT |
| `DenyRead` | Property excluded from query results |
| `DenySerialization` | Property excluded from JSON serialization |

## Row-Level Filtering

Restrict which rows a user can see — returns `404 Not Found` (not `403`) for hidden rows to avoid info leakage:

```csharp
public class OrderRowFilter : IRowLevelFilterProvider<Order>
{
    private readonly IHttpContextAccessor _http;

    public OrderRowFilter(IHttpContextAccessor http) => _http = http;

    public IQueryable<Order> ApplyFilter(IQueryable<Order> query)
    {
        var userId = _http.HttpContext?.User.FindFirst("sub")?.Value;
        return query.Where(o => o.CreatedBy == userId);
    }
}

// Register:
builder.Services.AddScoped<IRowLevelFilterProvider<Order>, OrderRowFilter>();
```

The filter is applied to both collection and single-entity queries.

## Controller Hooks

Override virtual methods in a partial controller extension to add validation, auditing, or side effects:

```csharp
public partial class OrdersController
{
    protected override Task OnBeforeCreate(Order entity, CancellationToken ct)
    {
        entity.CreatedBy = User.Identity?.Name ?? "unknown";
        entity.CreatedAt = DateTimeOffset.UtcNow;
        return Task.CompletedTask;
    }
}
```

| Hook | Trigger |
|------|---------|
| `OnBeforeQuery` | Before collection GET |
| `OnBeforeSingleResult` | Before single-entity GET |
| `OnBeforeCreate` / `OnAfterCreate` | Around POST |
| `OnBeforeReplace` / `OnAfterReplace` | Around PUT |
| `OnBeforePatch` / `OnAfterPatch` | Around PATCH |
| `OnBeforeDelete` / `OnAfterDelete` | Around DELETE |

## Security Checklist

- [ ] All entities with sensitive data have `[ODataAuthorize]`
- [ ] Immutable fields (CreatedBy, CreatedAt) have `DenyPatch = true, DenyPut = true`
- [ ] Internal/secret fields have `DenyRead = true` and/or `DenySerialization = true`
- [ ] Multi-tenant entities have `IRowLevelFilterProvider<T>` implementations
- [ ] Entities that must not be exposed have `[ODataIgnore]`
- [ ] Auth policies registered in `AuthorizationOptions` before `AddKoreForgeOData`
