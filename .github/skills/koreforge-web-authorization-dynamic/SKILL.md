---
name: koreforge-web-authorization-dynamic
description: "Use when applying or reviewing runtime-mutable, rule-store-driven authorization in a KoreForge app via MethodPermissionRule + PermissionsAuthorizationMiddleware. Choose this flavor when roles or conditions must change without redeploying or originate from a database/admin UI. Keywords: MethodPermissionRule, PermissionsAuthorizationMiddleware, IMethodPermissionStore, InMemoryMethodPermissionStore, IRequestPermissionEvaluator, PermissionConditionDelegate, AddDynamicMethodAuthorization, UseDynamicMethodAuthorization."
---

# KoreForge.Web.Authorization — Dynamic (Rule Store + Middleware) Flavor

> Read [koreforge-web-authorization](../koreforge-web-authorization/SKILL.md) first to confirm this is the right flavor.

## What it is

ASP.NET middleware (`PermissionsAuthorizationMiddleware`) that, for each request, resolves the matching `ControllerActionDescriptor`, looks up `MethodPermissionRule` entries for that `(controllerType, methodName)` key, and enforces them using the same `IRoleAuthorizationService` as the attribute flavor.

Rules live in an `IMethodPermissionStore`. The shipped `InMemoryMethodPermissionStore` takes an `IEnumerable<MethodPermissionRule>` at construction; replace it with your own store to source rules from a database, settings service, or admin UI.

## Required wiring

```csharp
// Program.cs

var rules = new List<MethodPermissionRule>
{
    new(
        typeFullName: typeof(DynamicDemoController).FullName!,
        methodName:   nameof(DynamicDemoController.ViewOrders),
        ruleKind:     RoleRuleKind.AnyOf,
        roles:        new[] { "Admin", "Sales" }),

    new(
        typeFullName: typeof(DynamicDemoController).FullName!,
        methodName:   nameof(DynamicDemoController.CreateOrder),
        ruleKind:     RoleRuleKind.AllOf,
        roles:        new[] { "Admin", "Sales" },
        condition:    static (ctx, user, ct) =>
        {
            var allowed = ctx.Request.Headers["X-Request-Source"]
                .ToString()
                .Equals("Internal", StringComparison.OrdinalIgnoreCase);
            return ValueTask.FromResult(allowed);
        }),
};

builder.Services.AddRoleAuthorizationCore();              // mandatory
builder.Services.AddDynamicMethodAuthorization(rules);    // registers store + evaluator + middleware

var app = builder.Build();
app.UseRouting();
app.UseAuthentication();
app.UseDynamicMethodAuthorization();   // BETWEEN authn and authz
app.UseAuthorization();
app.MapControllers();
```

`AddDynamicMethodAuthorization` registers:

- `IMethodPermissionStore` → `InMemoryMethodPermissionStore` (singleton, captures the supplied rules).
- `IRequestPermissionEvaluator` → `DefaultRequestPermissionEvaluator` (scoped).
- `PermissionsAuthorizationMiddleware` (scoped).

## `MethodPermissionRule` shape

| Property | Notes |
|---|---|
| `TypeFullName` | Always `typeof(MyController).FullName!`. Plain string match — no inheritance walking. |
| `MethodName` | Always `nameof(MyController.Action)`. Overloaded actions all share the same key — they all get the same rule set. |
| `RuleKind` | Same `AnyOf` / `AllOf` / `NotAnyOf` / `NotAllOf` semantics as attribute mode. |
| `Roles` | Whitespace entries are dropped; nulls become an empty set (always-pass). |
| `Condition` | Optional `PermissionConditionDelegate` — inline lambda preferred over a typed condition for this flavor. |

Multiple rules per action are AND-combined (each must pass).

## Rule evaluation order (per request)

`DefaultRequestPermissionEvaluator.IsAuthorizedAsync`:

1. Endpoint missing → **allow** (e.g. static files, health).
2. No `ControllerActionDescriptor` → **allow** (e.g. minimal API). **Dynamic mode does not apply to minimal APIs.**
3. No rules registered for this `(type, method)` → **allow**.
4. User not authenticated → **deny**.
5. For each rule: role check → if it passes and a condition is present, run it. Any failure → **deny**.
6. All rules passed → **allow**.

Denial logs a warning and writes HTTP 403 directly (no `ForbidResult` / no auth challenge).

## Inline conditions (`PermissionConditionDelegate`)

```csharp
public delegate ValueTask<bool> PermissionConditionDelegate(
    HttpContext httpContext,
    ClaimsPrincipal user,
    CancellationToken cancellationToken);
```

Common patterns from the sample:

```csharp
// Header-based
condition: static (ctx, _, _) =>
    ValueTask.FromResult(ctx.Request.Headers["X-Request-Source"] == "Internal")

// Time-of-day window
condition: static (_, _, _) =>
{
    var hour = DateTimeOffset.UtcNow.Hour;
    return ValueTask.FromResult(hour is >= 8 and <= 17);
}

// Tenant claim must equal query parameter
condition: static (ctx, user, _) =>
{
    var fromQuery = ctx.Request.Query["tenantId"].ToString();
    var fromClaim = user.FindFirst("tenant_id")?.Value;
    return ValueTask.FromResult(
        !string.IsNullOrEmpty(fromQuery) && fromQuery == fromClaim);
}
```

> Do not use `DateTimeOffset.UtcNow` directly in production conditions — capture an `ISystemClock` (see `koreforge-time`) when constructing the rule list, then close over it. The sample uses raw `DateTimeOffset.UtcNow` for brevity only.

Conditions must:
- Return `false` on failure; never throw.
- Honor `cancellationToken` (it is `HttpContext.RequestAborted`).
- Be cheap; they run on every matching request.

## Custom rule stores

To source rules from a database, settings service, or live-reload config, implement `IMethodPermissionStore` and register it **instead of** the default:

```csharp
services.AddRoleAuthorizationCore();
services.AddSingleton<IMethodPermissionStore, MyDbBackedPermissionStore>();
services.AddScoped<IRequestPermissionEvaluator, DefaultRequestPermissionEvaluator>();
services.AddScoped<PermissionsAuthorizationMiddleware>();
// then app.UseDynamicMethodAuthorization()
```

(Skip `AddDynamicMethodAuthorization` here because it would re-register the in-memory store.)

`GetRules` is called on every request. Cache aggressively inside the store; consider hot-reload via `KoreForge.Settings`.

## Testing

Unit-test the evaluator with a stub store:

```csharp
var store = Substitute.For<IMethodPermissionStore>();
store.GetRules(Arg.Any<MethodKey>()).Returns(new[] { rule });
var evaluator = new DefaultRequestPermissionEvaluator(store, new RoleAuthorizationService());
var ok = await evaluator.IsAuthorizedAsync(httpContext, default);
```

Integration-test the middleware via `WebApplicationFactory<Program>` exactly as the sample does.

## Common pitfalls

- Pipeline order wrong → middleware runs before authentication, `User.Identity.IsAuthenticated` is false, every protected endpoint returns 403.
- `TypeFullName` typo (e.g. nested type using `+` vs `.`) → no rule matches → endpoint silently **allowed**. Always use `typeof(T).FullName!`.
- Registering the same rule twice → both must pass; harmless if identical, dangerous if conditions differ.
- Trying to apply this to a minimal API endpoint → it does nothing. Use ASP.NET policy authorization for those.
- Forgetting to call `AddRoleAuthorizationCore()` → `IRoleAuthorizationService` is unresolved at first request.

## Checklist

- [ ] `AddRoleAuthorizationCore()` and `AddDynamicMethodAuthorization(rules)` (or custom store registration) called.
- [ ] `app.UseDynamicMethodAuthorization()` placed between `UseAuthentication()` and `UseAuthorization()`.
- [ ] `TypeFullName` produced via `typeof(T).FullName!` and `MethodName` via `nameof(...)`.
- [ ] Conditions return `false` on failure; clocks are injected, not `DateTimeOffset.UtcNow`.
- [ ] Custom stores cache reads — `GetRules` runs per request.
- [ ] Same action is **not** also decorated with `[RolesAuthorize]`.
- [ ] Tests cover allow + deny per rule; minimal-API endpoints documented as out-of-scope.
