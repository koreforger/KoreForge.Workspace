---
name: koreforge-web
description: "ROUTER skill for KoreForge.Web. Use to decide which sub-skill applies when working on REST APIs, authorization, health checks, or audit/persistence in a KoreForge ASP.NET application. Keywords: KoreForge.Web, RestApi, authorization, RolesAuthorize, dynamic permissions, health checks, ApiCallAudit."
---

# KoreForge.Web — Skill Router

`KoreForge.Web` is an umbrella package family. Pick the **sub-skill** that matches the work you are about to do. Do **not** apply this file's content as a checklist — it is purely a dispatcher.

## Sub-skills

| Sub-skill | Use when… |
|---|---|
| [koreforge-web-restapi-layers](../koreforge-web-restapi-layers/SKILL.md) | Scaffolding or modifying a 4-layer REST integration module: `KoreForge.RestApi.External.<Api>`, `Domain.<Api>`, `Internal.<Api>`, `Client.<Api>`. Refit rules, layer analyzers (API001–API007), audit hooks. |
| [koreforge-web-authorization](../koreforge-web-authorization/SKILL.md) | **Router** for any authorization work in `KoreForge.Web.Authorization`. Decides between attribute-based and dynamic rule-store flavors. Always read this first when adding/modifying authorization. |
| [koreforge-web-authorization-attribute](../koreforge-web-authorization-attribute/SKILL.md) | Decorating MVC controllers/actions with `[RolesAuthorize]`, building `IContextAuthorizationCondition` types. Compile-time, declarative. |
| [koreforge-web-authorization-dynamic](../koreforge-web-authorization-dynamic/SKILL.md) | Configuring `MethodPermissionRule` entries, `PermissionsAuthorizationMiddleware`, custom `IMethodPermissionStore` (DB-backed), inline `PermissionConditionDelegate`. Runtime-mutable. |
| [koreforge-web-healthchecks](../koreforge-web-healthchecks/SKILL.md) | Wiring `MapKfHealthEndpoints`, choosing `HealthTags` (`Ready`, `Live`, `Sql`, `Kafka`) for a registered check. |

## Decision tree

```
Need to call an external HTTP provider in a layered module?
  → koreforge-web-restapi-layers

Need to enforce who can call an MVC controller action?
  → koreforge-web-authorization (router) → pick attribute or dynamic

Adding /health, /health/ready, /health/live endpoints, or a new IHealthCheck?
  → koreforge-web-healthchecks
```

## What this package family is NOT

- Not a logging framework — see `koreforge-logging`.
- Not a metrics framework — see `koreforge-metrics` / `koreforge-metrics-aspnet`.
- Not a clock — `KoreForge.RestApi.Common.Observability` exposes `IUtcClock` for internal use, but consumers should still use `ISystemClock` from `koreforge-time`.
- Not the OData framework — see `koreforge-odata`.
