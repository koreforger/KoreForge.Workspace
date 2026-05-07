---
name: koreforge-web-authorization-attribute
description: "Use when applying or reviewing static, declarative role-based authorization on MVC controllers/actions in a KoreForge app via [RolesAuthorize] + IContextAuthorizationCondition. Choose this flavor when roles are known at compile time and live with the controller. Keywords: RolesAuthorize, RolesAuthorizeAttribute, RolesAuthorizationFilter, IContextAuthorizationCondition, AddRoleAuthorizationCore, RoleRuleKind."
---

# KoreForge.Web.Authorization — Attribute (Static) Flavor

> Read [koreforge-web-authorization](../koreforge-web-authorization/SKILL.md) first to confirm this is the right flavor.

## What it is

A `TypeFilterAttribute`-derived MVC authorization filter. The roles, the rule kind, and an optional `IContextAuthorizationCondition` type are baked into the controller code at compile time.

## Required wiring

```csharp
// Program.cs
builder.Services.AddControllers();
builder.Services.AddRoleAuthorizationCore();   // mandatory
builder.Services.AddScoped<BusinessHoursCondition>(); // each condition type, by its concrete type

// auth & policy
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts => { /* RoleClaimType = ClaimTypes.Role */ });
builder.Services.AddAuthorization();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

Pipeline does *not* need `UseDynamicMethodAuthorization`.

## Usage on a controller

`[RolesAuthorize(RoleRuleKind, string[]?, conditionType?)]` is applicable on classes and methods, multiple instances allowed.

```csharp
[ApiController]
[Route("api/attr")]
public sealed class AttributeDemoController : ControllerBase
{
    [HttpGet("admin-or-support")]
    [RolesAuthorize(RoleRuleKind.AnyOf, new[] { "Admin", "Support" })]
    public IActionResult AdminOrSupport() => Ok();

    [HttpGet("admin-and-supervisor")]
    [RolesAuthorize(RoleRuleKind.AllOf, new[] { "Admin", "Supervisor" })]
    public IActionResult AdminAndSupervisor() => Ok();

    [HttpGet("everyone-except-suspended")]
    [RolesAuthorize(RoleRuleKind.NotAnyOf, new[] { "Suspended" })]
    public IActionResult EveryoneExceptSuspended() => Ok();

    [HttpGet("not-trader-and-auditor")]
    [RolesAuthorize(RoleRuleKind.NotAllOf, new[] { "Trader", "Auditor" })]
    public IActionResult NotTraderAndAuditor() => Ok();

    [HttpGet("business-hours-only")]
    [RolesAuthorize(RoleRuleKind.AnyOf, new[] { "User", "Admin" }, typeof(BusinessHoursCondition))]
    public IActionResult BusinessHoursOnly() => Ok();
}
```

Stacking attributes is `AllOf` semantics across attributes — every attribute on the action (and its declaring class) must pass.

Apply `[RolesAuthorize]` on the **class** to enforce a baseline for every action; add narrower attributes per action when needed.

## Conditions (`IContextAuthorizationCondition`)

Use a typed condition when:
- Logic is reusable across multiple endpoints.
- Logic depends on injected services (clock, repository, options).
- You want unit tests on the condition itself.

```csharp
public sealed class BusinessHoursCondition : IContextAuthorizationCondition
{
    private readonly TimeProvider _clock;
    public BusinessHoursCondition(TimeProvider clock) => _clock = clock;

    public ValueTask<bool> EvaluateAsync(
        HttpContext httpContext,
        ClaimsPrincipal user,
        CancellationToken cancellationToken)
    {
        var now = _clock.GetUtcNow().TimeOfDay;
        return ValueTask.FromResult(now >= TimeSpan.FromHours(8) && now <= TimeSpan.FromHours(17));
    }
}
```

Rules:

- **You must register the condition type yourself** in DI (`AddScoped<TCondition>()`). The filter resolves it via `IServiceProvider.GetService(_conditionType)`. If it returns null → request is forbidden silently.
- The condition runs **only after** the role check passes. It is not evaluated for unauthenticated users.
- Do not throw inside `EvaluateAsync`; return `false`. Exceptions bubble out as 500.
- Honor `cancellationToken` (it is `HttpContext.RequestAborted`).

## Order of execution

For a single attribute:
1. `user.Identity.IsAuthenticated` check → otherwise `ForbidResult`.
2. `IRoleAuthorizationService.IsAuthorized(user, rule, roles)` → otherwise `ForbidResult`.
3. If condition type set, resolve it from DI; if missing or `EvaluateAsync` returns false → `ForbidResult`.

Empty `roles` array means "skip the role check (success)" — useful when only the condition matters. Pattern:

```csharp
[RolesAuthorize(RoleRuleKind.AnyOf, roles: null, typeof(IpAllowlistCondition))]
```

## Testing

```csharp
[Fact]
public async Task Forbids_when_user_lacks_required_role()
{
    var filter = new RolesAuthorizationFilter(
        RoleRuleKind.AllOf,
        new[] { "Admin" },
        new RolesAuthorizeAttribute.ConditionTypeHolder(null),
        new RoleAuthorizationService(),
        Substitute.For<IServiceProvider>());

    var ctx = MakeAuthorizationContext(user: PrincipalWith("User"));
    await filter.OnAuthorizationAsync(ctx);

    Assert.IsType<ForbidResult>(ctx.Result);
}
```

Use `WebApplicationFactory<Program>` for integration coverage; the sample project's `SampleApiIntegrationTests` is the reference.

## When to switch flavors

Move to the **dynamic** flavor when any of these become true:
- Operations need to change role lists without a deploy.
- Roles are stored in a database/admin UI.
- Many controllers share the same evolving rule and you want one source of truth.

## Checklist

- [ ] `AddRoleAuthorizationCore()` called.
- [ ] Every condition type registered in DI (`AddScoped<TCondition>()`).
- [ ] `RoleClaimType = ClaimTypes.Role` set on the JWT bearer handler.
- [ ] No `MethodPermissionRule` registered for the same action (no mixing per endpoint).
- [ ] Conditions return `false` on failure; never throw.
- [ ] Tests cover at least one happy and one denied path per attribute combination.
