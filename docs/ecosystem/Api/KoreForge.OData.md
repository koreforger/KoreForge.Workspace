# KoreForge.OData — API Reference

> Package: `KoreForge.OData` · Assemblies: `KoreForge.OData`, `KoreForge.OData.Generators`

## Registration

```csharp
IMvcBuilder AddKoreForgeOData(
    this IMvcBuilder mvcBuilder,
    Action<KoreForgeODataOptions>? configureOptions = null)

IServiceCollection AddEdmModelConfigurator<TConfigurator>(
    this IServiceCollection services)
    where TConfigurator : class, IEdmModelConfigurator
```

## `KoreForgeODataOptions`

```csharp
public sealed class KoreForgeODataOptions
{
    public int MaxPageSize { get; set; } = 100;
    public int MaxExpandDepth { get; set; } = 3;
    public int MaxNodeCount { get; set; } = 100;
    public bool EnableCount { get; set; } = true;
    public bool EnableFilter { get; set; } = true;
    public bool EnableOrderBy { get; set; } = true;
    public bool EnableSelect { get; set; } = true;
    public bool EnableExpand { get; set; } = true;
    public string RoutePrefix { get; set; } = "odata";
}
```

## Attributes

### `[ODataAuthorize]`

```csharp
public sealed class ODataAuthorizeAttribute : Attribute
{
    public string? ReadPolicy { get; set; }
    public string? CreatePolicy { get; set; }
    public string? UpdatePolicy { get; set; }
    public string? DeletePolicy { get; set; }
    public string? Roles { get; set; }
}
```

### `[ODataIgnore]`

```csharp
public sealed class ODataIgnoreAttribute : Attribute { }
```

### `[ODataPropertyRestriction]`

```csharp
public sealed class ODataPropertyRestrictionAttribute : Attribute
{
    public bool DenyRead { get; set; }
    public bool DenyPatch { get; set; }
    public bool DenyPut { get; set; }
    public bool DenySerialization { get; set; }
}
```

## `IEdmModelConfigurator`

```csharp
public interface IEdmModelConfigurator
{
    string ContextPrefix { get; }
    void Configure(ODataConventionModelBuilder builder);
}
```

## `KoreForgeODataController<TContext, TEntity, TKey>`

Base controller providing full CRUD with authorization and row-level filtering.

### Operations

| Method | Route | Description |
|--------|-------|-------------|
| `Get()` | `GET /odata/{prefix}/{set}` | Query with OData filters |
| `Get(key)` | `GET /odata/{prefix}/{set}({key})` | Single entity |
| `Post(entity)` | `POST /odata/{prefix}/{set}` | Create |
| `Put(key, entity)` | `PUT /odata/{prefix}/{set}({key})` | Full replace |
| `Patch(key, delta)` | `PATCH /odata/{prefix}/{set}({key})` | Partial update |
| `Delete(key)` | `DELETE /odata/{prefix}/{set}({key})` | Delete |

### Virtual Lifecycle Hooks

```csharp
OnBeforeQuery, OnBeforeSingleResult,
OnBeforeCreate, OnAfterCreate,
OnBeforeReplace, OnAfterReplace,
OnBeforePatch, OnAfterPatch,
OnBeforeDelete, OnAfterDelete
```

## Security

### `ODataEntityAuthorizationInfo`

```csharp
public sealed class ODataEntityAuthorizationInfo
{
    public string? ReadPolicy { get; init; }
    public string? CreatePolicy { get; init; }
    public string? UpdatePolicy { get; init; }
    public string? DeletePolicy { get; init; }
    public string[]? Roles { get; init; }

    public static ODataEntityAuthorizationInfo? FromEntityType(Type entityType)
    public Task<bool> IsAuthorizedAsync(
        IAuthorizationService authorizationService,
        ClaimsPrincipal user,
        ODataOperation operation)
}

public enum ODataOperation { Read, Create, Update, Delete }
```

### `IRowLevelFilterProvider<TEntity>`

```csharp
public interface IRowLevelFilterProvider<TEntity> where TEntity : class
{
    IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query);
}
```

### `PropertyRestrictionResolver`

```csharp
public static class PropertyRestrictionResolver
{
    public static IReadOnlySet<string> GetPatchDeniedProperties(Type entityType)
    public static IReadOnlySet<string> GetPutDeniedProperties(Type entityType)
    public static IReadOnlySet<string> GetReadDeniedProperties(Type entityType)
}
```

## Source Generator

`ODataSourceGenerator` is an `IIncrementalGenerator` that:

1. Scans for `[assembly: GenerateODataFor(typeof(TContext))]`
2. Analyzes each `DbContext` using `DbContextAnalyzer`
3. Emits one controller per non-ignored entity via `ControllerEmitter`
4. Emits one `IEdmModelConfigurator` per schema group via `EdmConfiguratorEmitter`
