# Swagger Controllers — Cross-Repo Specification

Status: Draft v1.0
Owner: KoreForge ecosystem + Event team
Scope: workspace-level coordination of three repos

This document captures the **interaction contract** between three repos. Each repo has its own per-repo specification; this one ties them together.

## 1. The four repos

| Repo | Visibility | Role | Spec |
|---|---|---|---|
| [`eco-system/KoreForge.SwaggerControllers`](../../../eco-system/KoreForge.SwaggerControllers) | public | .NET project template + runtime abstractions NuGet | [spec](../../../eco-system/KoreForge.SwaggerControllers/doc/specification.md) |
| [`event/Event.FraudIntegration.Data`](../../../event/Event.FraudIntegration.Data) | private | shared EF Core data package: DbContext, scaffolded entities, repositories, SQL schema scripts | [spec](../../../event/Event.FraudIntegration.Data/doc/specification.md) |
| [`event/Event.FraudIntegrationControllers`](../../../event/Event.FraudIntegrationControllers) | private | applies the template to 10 Nedbank fraud upstream APIs | [spec](../../../event/Event.FraudIntegrationControllers/doc/specification.md) |
| [`event/Event.ApiHost`](../../../event/Event.ApiHost) | public | self-hosted ASP.NET Core (HTTP.sys) app exposing the controllers | [spec](../../../event/Event.ApiHost/doc/specification.md) |

## 2. Dependency direction

```text
Event.ApiHost
    │
    ├── PackageReference: Event.FraudIntegrationControllers.AssemblyMarker (private feed)
    ├── PackageReference: Event.FraudIntegrationControllers.<Api>.V<N> (private feed) [12 of these]
    ├── PackageReference: Event.FraudIntegration.Data (private feed)
    ├── PackageReference: KoreForge.SwaggerControllers.Abstractions (nuget.org)
    ├── PackageReference: KoreForge.Web.Authorization (nuget.org)
    ├── PackageReference: KoreForge.AppLifecycle (nuget.org)
    ├── PackageReference: KoreForge.Logging.Serilog (nuget.org)
    ├── PackageReference: KoreForge.Metrics.AspNet (nuget.org)
    ├── PackageReference: Scalar.AspNetCore (nuget.org)
    └── PackageReference: Swashbuckle.AspNetCore (nuget.org)

Event.FraudIntegrationControllers.<Api>.V<N>
    │
    ├── PackageReference: KoreForge.SwaggerControllers.Abstractions (nuget.org)
    ├── PackageReference: Event.FraudIntegration.Data (private feed)  # used by <Api>PersistenceDecorator
    ├── PackageReference: Microsoft.AspNetCore.Mvc.Core
    ├── PackageReference: Refit + Refit.HttpClientFactory
    └── PackageReference: Microsoft.Extensions.Logging.Abstractions

Event.FraudIntegration.Data
    │
    ├── PackageReference: Microsoft.EntityFrameworkCore.SqlServer
    ├── PackageReference: Microsoft.EntityFrameworkCore.Design (build-time, for scaffold)
    └── PackageReference: Microsoft.Extensions.DependencyInjection.Abstractions

KoreForge.SwaggerControllers (template package)
    │
    └── (no runtime deps; ships content + bundled skill copy)

KoreForge.SwaggerControllers.Abstractions
    │
    ├── PackageReference: Microsoft.AspNetCore.Mvc.Core
    ├── PackageReference: Microsoft.Extensions.Http
    └── PackageReference: Microsoft.Extensions.Options
```

No `ProjectReference` anywhere. No vendoring. The dependency direction is strictly downstream; the host knows about the controllers, not the other way around.

## 3. Data flow at runtime

```text
Caller (user JWT or service API key)
    │
    ▼
Kestrel ─► Authentication (JWT bearer | ServiceApiKey)
              │
              ▼
         UseDynamicMethodAuthorization (KoreForge.Web)
              │  loads MethodPermissionRule[] from in-memory snapshot
              │  (snapshot rebuilt from MethodPermissionRules table at startup
              │   and on a 15-minute scheduled flow)
              ▼
         UseAuthorization
              │
              ▼
         MVC Controller (generated, `[Authorize]`, opt-in via marker assembly)
              │
              ▼
         <Api>LoggingDecorator (generated)
              │
              ▼
         <Api>BusinessDecorator (scaffolded — validation, transform)
              │
              ▼
         <Api>PersistenceDecorator (scaffolded — audit DB write to RequestAudit)
              │
              ▼
         <Api>Service (generated leaf)
              │  uses Refit IExternalClient + AuthDelegatingHandler (per-API auth)
              ▼
         Upstream Nedbank API
              │
              ▼
         Outcome<T> bubbles up; OutcomeExtensions.ToActionResult() at controller boundary.
```

## 4. Build-time data flow

```text
swagger.yml  ──[parse-swagger Copilot skill]──►  metadata.json
metadata.json ──[scr/generate.ps1, PS7]──►  Generated/*.g.cs + scaffolded files
Generated/*.g.cs + scaffolded files ──[dotnet build]──►  Event.FraudIntegrationControllers.<Api>.V<N>.dll
```

The `parse-swagger` skill lives at `c:\My\KoreForge2\.github\skills\parse-swagger\` (workspace) and is bundled byte-identical inside the template. Drift is detected in CI by `scr/sync-skill.ps1`.

## 5. Build order for a fresh workspace

1. `KoreForge.SwaggerControllers.Abstractions` — pack and publish (nuget.org or `artifacts/packages`).
2. `KoreForge.SwaggerControllers` template — pack and `dotnet new install`.
3. `Event.FraudIntegration.Data` — author `database/scripts/*.sql`, run them against a real SQL instance, scaffold entities into `Generated/`, build, pack, publish (private feed).
4. `Event.FraudIntegrationControllers` — scaffold from template, drop swaggers, generate, build (now resolves `Event.FraudIntegration.Data`), pack, publish (private feed).
5. `Event.ApiHost` — restore against private + nuget.org + `artifacts/packages`, run `verify-database.ps1`, build, run.

## 6. Versioning policy across the boundary

- A breaking change in `KoreForge.SwaggerControllers.Abstractions` requires:
  1. Major version bump of the abstractions package.
  2. Major version bump of the template package (because the template's pinned abstractions version moves).
  3. Re-generation of every API library in `Event.FraudIntegrationControllers` (their generator output may change).
  4. Major version bump of every regenerated API library package.
  5. Update `PackageReference` in `Event.ApiHost`.
- A pure-additive change to abstractions is a minor bump; consumers re-pin at their convenience.
- A change to `generate.ps1` that produces different `*.g.cs` content is a minor bump of the template package only — but consumer regeneration is still required.

## 7. Authorization rule wiring

Generated controllers carry `[Authorize]` only — they are **policy-name-agnostic**. The host owns the rule table (`MethodPermissionRules`) and constructs the in-memory `MethodPermissionRule[]` from it. The seed mapping `Phishing.Administrator -> *` (a single row in the table) is the only built-in role; further roles and per-method narrowings are operations data, not code.

The generated `Permissions.<Operation>` constants exist so the host's rule table can reference operations by their stable string identifier (`<RootNamespace>.<ApiName>.V<N>.<Operation>`) without taking a compile-time dependency on every type name.

## 8. Service-to-service authentication

Service callers present `X-Service-Key`. The host authenticates via `ServiceApiKeyAuthenticationHandler` against `ServiceClients` (PBKDF2-SHA512). On success, the principal carries `Role = Service:<ClientId>`, which `MethodPermissionRules` can reference like any other role. This mechanism is **owned exclusively by `Event.ApiHost`** — neither the template nor `KoreForge.Web` knows about it. Other hosts wanting service-to-service auth re-implement the handler.

## 9. Configuration governance

`Event.FraudIntegration.Data` is the **single owner** of the SQL schema and all access code. `Event.ApiHost` and `Event.FraudIntegrationControllers` are both consumers: the host owns runtime composition (DI, middleware, lifecycle), the controllers package owns business + persistence behavior — but both go through the same DbContext + repository interfaces shipped by `Event.FraudIntegration.Data`. Any schema change is a single PR in that one repo plus a version bump that ripples to its two consumers.

The `RequestAudit` table is therefore not a cross-repo coupling — it is a normal table owned by the data lib and accessed by every consumer through `IRequestAuditRepository`.

## 10. Open governance items

- Decide whether `KoreForge.SwaggerControllers.Abstractions` should be split (e.g. an `.Outcome` package usable by non-controller code). Defer until a second consumer asks.
- Decide whether `IPrincipalRoleResolver` should move into `KoreForge.Web` so other hosts can share the abstraction. Defer until a second host needs it.
- Confirm the private NuGet feed identity for `Event.FraudIntegrationControllers.*`. Until decided, packages stay in the workspace `artifacts/packages` feed only.

## 11. Document inventory updates

When the per-repo specs are first reviewed, add the following rows to [docs/ecosystem/documentation-inventory.md](../../documentation-inventory.md):

- `eco-system/KoreForge.SwaggerControllers/doc/specification.md` — Specification
- `eco-system/KoreForge.SwaggerControllers/doc/notes/implementation-plan.md` — Notes
- `event/Event.FraudIntegration.Data/doc/specification.md` — Specification (private)
- `event/Event.FraudIntegration.Data/doc/notes/implementation-plan.md` — Notes (private)
- `event/Event.FraudIntegrationControllers/doc/specification.md` — Specification (private)
- `event/Event.FraudIntegrationControllers/doc/notes/implementation-plan.md` — Notes (private)
- `event/Event.ApiHost/doc/specification.md` — Specification
- `event/Event.ApiHost/doc/notes/implementation-plan.md` — Notes
- `docs/ecosystem/specifications/swagger-controllers.md` — this document
