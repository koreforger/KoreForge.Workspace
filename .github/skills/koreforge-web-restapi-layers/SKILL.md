---
name: koreforge-web-restapi-layers
description: "Use when scaffolding, implementing, or reviewing a 4-layer REST integration module (KoreForge.RestApi.External/Domain/Internal/Client.<ApiName>). Covers Refit rules, the API001–API007 analyzers, EF audit (ApiCallAudit), and the new-api.ps1 scaffold. Keywords: RestApi, External, Domain, Internal, Client, Refit, ApiResponse, new-api.ps1, ApiCallAudit, ApiGatewayDbContext, AddCommonObservability, AddCommonPersistence."
---

# KoreForge.Web — RestApi 4-Layer Module Skill

## When to use

Use this skill when the work touches **any** of:

- A `KoreForge.RestApi.External.<Api>`, `…Domain.<Api>`, `…Internal.<Api>`, or `…Client.<Api>` project.
- Adding a new external HTTP provider integration.
- Fixing analyzer errors `API001`–`API007`.
- Writing or reading audit data via `IApiAuditRepository` / `ApiCallAudit`.
- The internal host (`KoreForge.RestApi.Host.Internal`) wiring.

Do **not** use this skill for authorization or health-check work — see the router in [koreforge-web](../koreforge-web/SKILL.md).

## The four layers

```
External.<Api>   transport only (Refit), all types internal
Domain.<Api>     orchestration + EF audit, public domain models
Internal.<Api>   ASP.NET controllers / minimal APIs (internal)
Client.<Api>     SDK that calls Internal over HTTP
```

Allowed reference graph (analyzer-enforced):

```
External  ⇍ Domain ⇍ Internal
                    ⇍ Client
```

## Scaffold

```powershell
.\scr\new-api.ps1 -ApiName NedCase -DbSchema Audit -TableMode Single -EnableAuditing $true
```

Always scaffold — never hand-create the four projects.

## External layer rules (analyzer-enforced)

- All types **`internal`** (`API001`).
- Refit methods return **`Task<ApiResponse<T>>`** — never `Task<T>` (`API005`).
- Every Refit method ends with **`CancellationToken ct = default`** (`API006`).
- No Polly, no retries, no fallbacks. Transport only.
- DTOs are immutable (`init`-only).
- May not reference Domain/Internal/Client (`API002`).
- `HttpClient` may not be `new`'d here (`API007` warning) — use `AddRefitClient`.

```csharp
internal interface INedCaseRefitClient
{
    [Get("/v1/cases/{id}")]
    Task<ApiResponse<NedCaseResponseDto>> GetCaseAsync(
        string id,
        CancellationToken ct = default);
}

internal sealed class NedCaseResponseDto
{
    public string Id { get; init; } = default!;
    public DateTimeOffset CreatedAt { get; init; }
}
```

DI extension is the *only* public surface in External:

```csharp
public static IServiceCollection AddNedCaseExternal(
    this IServiceCollection services,
    IConfiguration configuration);
```

Configuration binds to `ExternalApis:<ApiName>` (`AddExternalApiOptions`).

## Domain layer rules

- Public domain models are *different shapes* from External DTOs — never re-export Refit DTOs.
- Use cases live in `…Domain.<Api>.UseCases` and depend on the External Refit interface, `IApiAuditRepository`, and `ITracer`.
- Map non-2xx `ApiResponse<T>` to typed exceptions (e.g. `ExternalSystemFaultException`).
- May not reference Internal or Client (`API003`).
- Write redacted request/response into `ApiCallAudit` per call.

## Internal layer rules

- Class library (no host of its own); the only host is `KoreForge.RestApi.Host.Internal`.
- Controllers/minimal APIs are `internal`.
- May not reference External (`API004`) — go through Domain.
- Errors return `ProblemDetails` with `correlationId` from `HttpContext.TraceIdentifier`.

## Client layer rules

- Public SDK consumed by other internal services.
- Only layer permitted to `new HttpClient()` (analyzer suppresses `API007` here).
- Calls Internal endpoints, not External.

## Common services to register on the host

```csharp
builder.Services
    .AddCommonObservability()                   // IUtcClock + ITracer (ActivityTracer)
    .AddCommonPersistence(builder.Configuration) // ApiGatewayDbContext + IApiAuditRepository + retention hosted service
    .AddNedCaseExternal(builder.Configuration)
    .AddNedCaseDomain();
```

`AddCommonPersistence` reads `Persistence:ConnectionStringName` (default `ApiGateway`). If the connection string is missing and `AllowInMemoryFallback` is true, it falls back to EF in-memory (dev only). It also registers `AuditRetentionHostedService` driven by `AuditStoreOptions.RetentionDays`.

## Audit entity

`ApiCallAudit` (schema `gateway`) captures: `ApiName`, `Operation`, `Direction` (`Outbound`/`Inbound`), `StatusCode`, `CorrelationId`, request/response timestamps + duration, redacted `RequestPayload`/`ResponsePayload`. Indexes are pre-created on `ApiName`, `CorrelationId`, and `(ApiName, Operation, RequestTimestampUtc)`.

Apply `AuditRedactionOptions` to strip secrets/PII before persisting.

## Analyzer reference

| ID | Severity | Meaning |
|----|----------|---------|
| API001 | Error | External type is not `internal`. |
| API002 | Error | External references Domain/Internal/Client. |
| API003 | Error | Domain references Internal/Client. |
| API004 | Error | Internal references External. |
| API005 | Error | External Refit method does not return `Task<ApiResponse<T>>`. |
| API006 | Error | External Refit method missing trailing `CancellationToken`. |
| API007 | Warning | `new HttpClient(...)` outside Client layer. |

Run `dotnet build -warnaserror` — analyzers also fire at *compilation end* for cross-project reference checks.

## Checklist

- [ ] Scaffolded with `new-api.ps1`.
- [ ] All External types `internal`; all Refit methods `Task<ApiResponse<T>>` + trailing `CancellationToken`.
- [ ] No Polly/retries in External.
- [ ] Domain maps to its own model; never returns External DTOs.
- [ ] Internal returns `ProblemDetails` with correlation id.
- [ ] Client is the only layer constructing `HttpClient`.
- [ ] `AddCommonObservability` + `AddCommonPersistence` wired on the host.
- [ ] `ApiCallAudit` written per outbound call with redaction.
- [ ] `dotnet build -warnaserror` is clean.
