---
name: koreforge-web-authorization
description: "ROUTER skill for KoreForge.Web.Authorization. Use FIRST whenever you need to enforce role-based access on an MVC controller/action in a KoreForge ASP.NET app. Helps you choose between the attribute (static) and dynamic (rule-store middleware) flavors. Keywords: KoreForge.Web.Authorization, RolesAuthorize, RoleRuleKind, MethodPermissionRule, PermissionsAuthorizationMiddleware, IRoleAuthorizationService, IContextAuthorizationCondition, AddRoleAuthorizationCore, AddDynamicMethodAuthorization."
---

# KoreForge.Web.Authorization — Skill Router

`KoreForge.Web.Authorization` ships **two independent enforcement mechanisms** that share the same role-evaluation core. Pick one per controller/action — they can co-exist in the same app, but mixing both on the same endpoint is forbidden (see "Mixing").

This file is a **router**. After choosing the flavor, load the matching sub-skill before writing code.

## The shared core (always present)

| Building block | Purpose |
|---|---|
| `IRoleAuthorizationService` / `RoleAuthorizationService` | Evaluates role claims (`ClaimTypes.Role`) using a `RoleRuleKind`. |
| `RoleRuleKind` | `AnyOf`, `AllOf`, `NotAnyOf`, `NotAllOf`. |
| `IContextAuthorizationCondition` | Optional secondary async predicate on `HttpContext` + `ClaimsPrincipal`, evaluated **after** the role check passes. Used by both flavors (attribute = type, dynamic = delegate). |
| `services.AddRoleAuthorizationCore()` | **Required** for both flavors. Registers the role service. |

Empty `roles` collection → role check passes (`true`). The condition still runs.

Failure of either the role check or the condition produces:
- Attribute mode: `ForbidResult` (HTTP 403 via auth scheme challenge).
- Dynamic mode: HTTP 403 written directly by the middleware.

Unauthenticated user → both flavors deny.

## Decision: attribute vs dynamic

Use this matrix to pick. **If unsure, default to attribute mode.**

| Question | Attribute (static) | Dynamic (rule store) |
|---|---|---|
| Are the roles known at compile time? | ✅ | — |
| Do you want them visible at the call site (controller code)? | ✅ | — |
| Must roles or conditions change without redeploying? | — | ✅ |
| Are rules sourced from a database / config service / admin UI? | — | ✅ |
| Need a custom store (DB-backed `IMethodPermissionStore`)? | — | ✅ |
| Want strongly-typed reusable conditions (DI-resolved)? | ✅ (`IContextAuthorizationCondition` type) | ✅ but inline `PermissionConditionDelegate` is more common |
| Need the rule to run **before** MVC model binding? | — | ✅ (middleware runs earlier in pipeline) |
| Need to apply the same rule to many actions? | Decorate the controller class with `[RolesAuthorize]` | Register many `MethodPermissionRule` entries (one per action) |

→ **Static / declarative** → load [koreforge-web-authorization-attribute](../koreforge-web-authorization-attribute/SKILL.md)
→ **Runtime / mutable** → load [koreforge-web-authorization-dynamic](../koreforge-web-authorization-dynamic/SKILL.md)

## Mixing rules

- Same app: ✅ allowed. Most KoreForge apps use attribute mode for the bulk of endpoints and dynamic mode only for rules an operator must change at runtime.
- Same action: ❌ do not stack `[RolesAuthorize]` and a `MethodPermissionRule` on the same controller method. Both will execute and the request must pass both — this is almost always a bug.

## Required pipeline ordering (host)

The dynamic middleware must sit **between** `UseAuthentication` and `UseAuthorization`:

```csharp
app.UseRouting();
app.UseAuthentication();
app.UseDynamicMethodAuthorization();  // only if dynamic is used
app.UseAuthorization();
app.MapControllers();
```

Attribute mode requires no pipeline change beyond standard `UseAuthentication`/`UseAuthorization`.

## Authentication is *not* configured by this library

`KoreForge.Web.Authorization` assumes `ClaimsPrincipal` is already populated by an authentication handler (typically JWT bearer with `RoleClaimType = ClaimTypes.Role`). Wire `AddAuthentication().AddJwtBearer(...)` yourself — see the `KoreForge.Web.Authorization.Sample` project for a reference.

## Common pitfalls (apply to both flavors)

- Forgetting `services.AddRoleAuthorizationCore()` → DI resolution failure on first request.
- JWT not setting `RoleClaimType = ClaimTypes.Role` → role claims unreadable; everything denies.
- Using a non-MVC endpoint (minimal API) → **dynamic** mode skips the request (no `ControllerActionDescriptor`) and **attribute** mode does not apply at all. Use ASP.NET's standard policy authorization for minimal APIs instead.
- Anonymous endpoints intentionally bypass: dynamic mode allows (no rule found = allow); attribute mode is opt-in (no attribute = no enforcement). Apply `[Authorize]` separately when you need the auth challenge.

## Sample project reference

`tst/KoreForge.Web.Authorization.Sample` demonstrates both flavors side-by-side with JWT bearer, `BusinessHoursCondition` (typed `IContextAuthorizationCondition`), and inline tenant/header conditions. Read it before introducing a new pattern.
