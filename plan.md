# Event Fraud Integration — Implementation Plan

**Date:** 2026-05-05  
**Status:** In Progress

---

## Repos

| Repo | Path | Branch |
|------|------|--------|
| KoreForge.SwaggerControllers | `eco-system/KoreForge.SwaggerControllers` | development |
| Event.FraudIntegration.Data | `event/Event.FraudIntegration.Data` | development |
| Event.FraudIntegrationControllers | `event/Event.FraudIntegrationControllers` | development |
| Event.ApiHost | `event/Event.ApiHost` | development |

---

## Current State

| Repo | Phase | Last Commit | Notes |
|------|-------|-------------|-------|
| KoreForge.SwaggerControllers | Phase 1–5 complete | 826f0cf pushed | Abstractions + template + generator + 33/33 snapshot tests + docs |
| Event.FraudIntegration.Data | Phase 1 complete | c7be389 pushed | 9 SQL scripts + apply/verify scripts; Phase 2+ (DbContext, repos) not started |
| Event.FraudIntegrationControllers | Phase 0 skeleton | pushed | slnx, Directory.Build.props, NuGet.config, scr/, doc/ only |
| Event.ApiHost | Phase 0 skeleton | pushed | slnx, Directory.Build.props, NuGet.config, scr/, doc/ only |

### Available Swaggers (temp/aft-detection-core-external-api/swaggers/)

All have `swagger.<ApiName>.yml` + `metadata.json` already present.

| API | Versions |
|-----|---------|
| CashoutOrchestrator | v1 |
| NedbankIdMFA | v1 |
| Party | v1 |
| Person | v1 |
| SASVIFinancialCrimeCaseManagement | v1 |
| SuspendAccount | v1, v2 |
| UserDetails | v1 |
| UserFederationDetail | v1 |
| UserGroupFederationDetail | v1, v2 |
| UserstateForNID | v1 |

> **Note:** metadata.json files in temp are in the DCS parse-swagger format (`folderVersion`, `operationKey`, `csharpType`, etc.).
> The KoreForge `generate.ps1` expects the Sample format (`version`, `name`, `type`, etc.).
> Each swagger must go through the parse-swagger SKILL to produce KoreForge-format metadata.json before running `generate.ps1`.

---

## Constraints

- **No HTTP.sys** — Kestrel only everywhere
- **Cert config** — stored in SQL `Config.Settings` table, not in appsettings files
- **Authorization** — `Permissions.g.cs` already emits `public const string <OpName> = "<Namespace>.<OpName>"` per operation. The host wires these as ASP.NET Core authorization policies via `AddKoreForgeAuthorization`. No hand-writing of policy names needed.
- **Auth scheme** — JWT Bearer + ServiceApiKey (two schemes). `UseDynamicMethodAuthorization` (KoreForge.Web) loads `MethodPermissionRule[]` from the `MethodPermissionRules` SQL table at startup and on a 15-min scheduled refresh.
- **Net10.0** — all projects target net10.0; use `FrameworkReference Microsoft.AspNetCore.App` (not MVC NuGet)
- **One type per file** — TreatWarningsAsErrors=true
- **Local feed only** — workspace `artifacts/packages` (no private feed yet); `packageSourceMapping KoreForge.* → koreforge-local`
- **SQL** — container `streaming-sqledge`, port 14334, SA password `Streaming!Pass123`, DB `FraudIntegration`

---

## Tier 1 — Event.FraudIntegration.Data Phase 2 + 3

> Prerequisite for Tier 3 (ApiHost settings) and Tier 5 (ApiHost data). Can start immediately.

### Phase 2 — EF Core + Scaffold

- [ ] `src/Event.FraudIntegration.Data/Event.FraudIntegration.Data.csproj` (net10.0, EFCore.SqlServer, EFCore.Design)
- [ ] `FraudIntegrationDbOptions.cs` — connection string option
- [ ] `FraudIntegrationDbContext.cs` — partial, for hand-written overrides
- [ ] `config/scaffold-config.json` — EF scaffold config pointing at SQL
- [ ] `scr/scaffold-db.ps1` — runs `dotnet ef dbcontext scaffold` into `Generated/`
- [ ] Run scaffold — review and commit `Generated/` entities + partial context
- [ ] Add project to `Event.FraudIntegration.Data.slnx`

### Phase 3 — Repositories + DI

- [ ] `FraudIntegrationDataServiceCollectionExtensions.cs`
- [ ] 6 repository interfaces (one type per file):
  - `ISettingsRepository` (Config.Settings)
  - `IMethodPermissionRuleRepository` (Config.MethodPermissionRules)
  - `IServiceClientRepository` (Config.ServiceClients)
  - `IServiceClientScopeRepository` (Config.ServiceClientScopes)
  - `IAuditRepository` (Audit.RequestAudit)
- [ ] 6 repository implementations (one type per file)
- [ ] `tst/Event.FraudIntegration.Data.Tests/` — unit tests + PublicApiApprovalTests
- [ ] `dotnet test` green
- [ ] `scr/build-pack.ps1` → copy `.nupkg` to `artifacts/packages`
- [ ] Commit + push

---

## Tier 2A — Event.FraudIntegrationControllers Scaffold Completion

> Finishes the skeleton so generate.ps1 can run. Start immediately.

- [ ] `NuGet.config` — add `packageSourceMapping` for `KoreForge.*` → koreforge-local (already has the source)
- [ ] Update `Directory.Packages.props` — pin `KoreForge.SwaggerControllers.Abstractions 0.0.0-alpha.0.3`, add `Refit.HttpClientFactory`
- [ ] `swaggers/` directory (empty, tracked with .gitkeep)
- [ ] `src/Event.FraudIntegrationControllers.AssemblyMarker/` — csproj + `AssemblyMarker.cs`
- [ ] Copy `scr/generate.ps1` from template (rename from `.txt`)
- [ ] Add projects to slnx
- [ ] `dotnet build` → 0 errors
- [ ] Commit + push

---

## Tier 2B — Event.ApiHost Dev-Bootstrap SQL

> Seeds the 5 Config tables with dev-only rows. Start immediately.

- [ ] `database/seed/dev-bootstrap.sql` — insert rows into:
  - `Config.Settings` (Kestrel cert path/name, JWT issuer/audience, connection string template)
  - `Config.ServiceClients` (a test service client)
  - `Config.ServiceClientScopes` (scopes for the test client)
  - `Config.MethodPermissionRules` (seed rule: `*.Administrator` → `*`)
- [ ] `scr/verify-database.ps1` — asserts seed rows exist
- [ ] Apply seed + verify → green
- [ ] Commit + push

---

## Tier 4 — Event.FraudIntegrationControllers Per-API Generation

> **NOT BLOCKED** — swagger files are in `temp/aft-detection-core-external-api/swaggers/`.

For each of the 12 API versions:

1. Copy `swagger.<ApiName>.yml` to `swaggers/<ApiName>/v<N>/swagger.yml`
2. Run parse-swagger SKILL on `swagger.yml` → produce KoreForge-format `metadata.json`
3. Run `scr/generate.ps1` → emits `src/<RootNamespace>.<ApiName>.V<N>/Generated/`
4. Scaffold files emitted once (BusinessDecorator, PersistenceDecorator, ServiceCollectionExtensions, csproj)
5. Add project to slnx
6. `dotnet build` → 0 errors
7. Commit per API (or batch)

Then:
- [ ] `tst/Event.FraudIntegrationControllers.Tests/` — PublicApiApprovalTests
- [ ] `scr/build-pack.ps1` → copy `.nupkg` + `.snupkg` to `artifacts/packages`
- [ ] Commit + push

---

## Tier 3 — Event.ApiHost Phase 2–5

> Requires Tier 1 packed (for DB repositories). Can start Program.cs skeleton before Tier 1 is done.

### Phase 2 — Program.cs + Kestrel

- [ ] `src/Event.ApiHost/Event.ApiHost.csproj` — net10.0, FrameworkReference, KoreForge packages
- [ ] `Program.cs` — minimal host: Kestrel, Serilog, services, controllers
- [ ] `Settings/AppSettingsRepository.cs` — reads from SQL `Config.Settings` at startup
- [ ] Kestrel cert loaded from setting key `Kestrel:CertPath` / `Kestrel:CertPassword` (stored in SQL)

### Phase 3 — Authentication

- [ ] `Auth/ServiceApiKeyAuthenticationHandler.cs` — validates `X-Api-Key` header against `Config.ServiceClients` + `Config.ServiceClientScopes`
- [ ] `Auth/ServiceClientStore.cs` — in-memory cache of service clients; refreshed on startup
- [ ] Register JWT Bearer + ServiceApiKey as two authentication schemes

### Phase 4 — Authorization

- [ ] `Auth/MethodPermissionRuleFactory.cs` — loads `Config.MethodPermissionRules` from DB → builds `MethodPermissionRule[]`
- [ ] Call `builder.Services.AddKoreForgeAuthorization(...)` registering each `Permissions.<OpName>` const string as an ASP.NET Core named policy
- [ ] `UseDynamicMethodAuthorization` middleware — loads snapshot at startup, refreshed every 15 min via scheduled lifecycle step

### Phase 5 — Lifecycle Steps

- [ ] `Lifecycle/Startup/LoadSettingsStep.cs` — reads Config.Settings → populates in-memory store
- [ ] `Lifecycle/Startup/LoadServiceClientsStep.cs`
- [ ] `Lifecycle/Startup/LoadMethodPermissionRulesStep.cs`
- [ ] `Lifecycle/Scheduled/RefreshPermissionRulesStep.cs` — 15-min interval
- [ ] `Lifecycle/Shutdown/FlushAuditStep.cs`
- [ ] Tests + commit + push

---

## Tier 5 — Event.ApiHost Phase 6 (Wire Controllers)

> Requires Tier 4 packed.

- [ ] Update `Directory.Packages.props` — add reference to `Event.FraudIntegrationControllers.AssemblyMarker` + all 12 per-API packages
- [ ] `Composition/ControllerRegistration.cs` — calls `AddSwaggerControllers<AssemblyMarker>()`
- [ ] Swashbuckle + Scalar OpenAPI endpoints
- [ ] `GET /healthz` endpoint
- [ ] Integration tests (spin up TestServer, hit `/healthz` and one API endpoint)
- [ ] Commit + push

---

## Package Versions (local feed)

| Package | Version |
|---------|---------|
| KoreForge.SwaggerControllers.Abstractions | 0.0.0-alpha.0.3 |
| KoreForge.SwaggerControllers (template) | 0.0.0-alpha.0.3 |

> All other KoreForge.* packages resolve from nuget.org until a new local pack is needed.
