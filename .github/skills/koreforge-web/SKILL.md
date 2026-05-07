---
name: koreforge-web
description: "Use when scaffolding, implementing, or reviewing a multi-layer REST API module in a KoreForge application (KoreForge.Web / KoreForge.RestApi framework). Covers External/Domain/Internal/Client layer contracts, Refit rules, analyzer enforcement, EF audit, Domain use cases, Internal controllers, Client SDK. Keywords: RestApi, External, Domain, Internal, Client, Refit, ApiResponse, new-api.ps1."
---

# KoreForge Web (RestApi Framework) Skill

## Overview

`KoreForge.Web` is a 4-layer REST API integration framework. Each external API provider gets its own set of four projects scaffolded by `new-api.ps1`. Roslyn analyzers enforce layer boundaries at build time.

```
KoreForge.RestApi.External.<ApiName>   — transport only (Refit, internal types)
KoreForge.RestApi.Domain.<ApiName>     — use cases, domain models, EF audit
KoreForge.RestApi.Internal.<ApiName>   — ASP.NET controllers/minimal API endpoints
KoreForge.RestApi.Client.<ApiName>     — SDK for consumers of the internal API
```

## Packages

```xml
<!-- Each layer is a separate package -->
<PackageReference Include="KoreForge.RestApi.Common.Abstractions" />
<PackageReference Include="KoreForge.RestApi.Common.Observability" />
```

Scaffold generates project files with correct package references.

## Step 1 — Scaffold a New API Module

```powershell
.\scr\new-api.ps1 -ApiName NedCase -DbSchema Audit -TableMode Single -EnableAuditing $true
```

This creates all four layers plus architecture tests.

## Step 2 — Configure appsettings

```json
{
  "ConnectionStrings": {
    "Audit": "Server=.;Database=AuditDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "ExternalApis": {
    "NedCase": {
      "BaseUrl": "https://api.provider.com",
      "Timeout": "00:00:30"
    }
  },
  "Domains": {
    "NedCase": { "EnableAuditing": true }
  }
}
```

## Layer Rules

### External Layer — `KoreForge.RestApi.External.<ApiName>`

**Purpose**: Transport surface only. No business logic.

Critical rules enforced by analyzers:
- All interfaces and DTOs must be **`internal`** — never `public`
- Every Refit method must return `Task<ApiResponse<T>>` — never `Task<T>`
- Every method must have `CancellationToken ct = default` as the last parameter
- No Polly, no retry policies, no fallback logic
- Namespace must start with `KoreForge.RestApi.External.<ApiName>`

```csharp
// CORRECT
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
    public string Title { get; init; } = default!;
    public DateTimeOffset CreatedAt { get; init; }
}

// WRONG — analyzer violation
public interface INedCaseRefitClient { }           // KRW001: must be internal
Task<NedCaseResponseDto> GetCaseAsync(...)         // KRW002: must return Task<ApiResponse<T>>
Task<ApiResponse<NedCaseResponseDto>> GetCase()   // KRW003: CancellationToken required
```

External DI extension exposes a single public method:

```csharp
public static IServiceCollection AddNedCaseExternal(
    this IServiceCollection services,
    IConfiguration configuration)
```

### Domain Layer — `KoreForge.RestApi.Domain.<ApiName>`

**Purpose**: Orchestrate External calls, apply business rules, persist audit records.

```csharp
// Domain model — public, different shape from External DTO
public sealed class NedCase
{
    public string Id { get; init; } = default!;
    public string Title { get; init; } = default!;
    public DateTimeOffset CreatedAt { get; init; }
}

// Use case interface
public interface IGetNedCaseUseCase
{
    Task<NedCase> ExecuteAsync(string id, CancellationToken ct = default);
}

// Implementation — maps from ApiResponse<T> → domain model
internal sealed class GetNedCaseUseCase : IGetNedCaseUseCase
{
    private readonly INedCaseRefitClient _client;
    private readonly INedCaseAuditWriter _audit;

    public GetNedCaseUseCase(INedCaseRefitClient client, INedCaseAuditWriter audit)
    {
        _client = client;
        _audit  = audit;
    }

    public async Task<NedCase> ExecuteAsync(string id, CancellationToken ct = default)
    {
        var response = await _client.GetCaseAsync(id, ct);

        if (!response.IsSuccessStatusCode)
            throw new ExternalSystemFaultException("NedCase", response.StatusCode);

        await _audit.WriteAsync(id, response, ct);

        return new NedCase
        {
            Id        = response.Content!.Id,
            Title     = response.Content.Title,
            CreatedAt = response.Content.CreatedAt,
        };
    }
}
```

Audit pattern:
- Write redacted `RequestJson` / `ResponseJson` into per-API audit EF tables
- Use EF Core context scaffolded from the DB schema (see `koreforge-data` skill)

### Internal Layer — `KoreForge.RestApi.Internal.<ApiName>`

**Purpose**: Expose curated HTTP endpoints for internal consumers.

```csharp
[ApiController]
[Route("api/ned-case")]
internal sealed class NedCaseController : ControllerBase
{
    private readonly IGetNedCaseUseCase _getCase;

    public NedCaseController(IGetNedCaseUseCase getCase) => _getCase = getCase;

    [HttpGet("{id}")]
    public async Task<ActionResult<NedCase>> GetAsync(string id, CancellationToken ct)
    {
        try
        {
            var result = await _getCase.ExecuteAsync(id, ct);
            return Ok(result);
        }
        catch (ExternalSystemFaultException ex)
        {
            return Problem(
                detail: ex.Message,
                statusCode: StatusCodes.Status502BadGateway,
                extensions: new Dictionary<string, object?> { ["correlationId"] = HttpContext.TraceIdentifier });
        }
    }
}
```

- Return `ProblemDetails` on errors with correlation id
- Controllers are `internal` — surfaced via assembly registration

### Client Layer — `KoreForge.RestApi.Client.<ApiName>`

**Purpose**: SDK for callers of the Internal API. Wraps Refit calls to Internal endpoints.

```csharp
// Calling the client from another service
public sealed class NedCaseApiClient
{
    private readonly INedCaseInternalClient _client;

    public NedCaseApiClient(INedCaseInternalClient client) => _client = client;

    public async Task<NedCase> GetCaseAsync(string id, CancellationToken ct)
    {
        var response = await _client.GetCaseAsync(id, ct);
        return response.IsSuccessStatusCode
            ? response.Content!
            : throw new InvalidOperationException(response.Error?.Content);
    }
}
```

## Analyzer Violations

| Code | Rule | Fix |
|------|------|-----|
| `KRW001` | External type is `public` | Make it `internal` |
| `KRW002` | Refit method returns `Task<T>` | Change to `Task<ApiResponse<T>>` |
| `KRW003` | Refit method missing `CancellationToken` | Add `CancellationToken ct = default` |
| `KRW004` | External references Domain types | External must be self-contained |
| `KRW005` | Domain references Internal types | One-way dependency only |

Run `dotnet build -warnaserror` to catch all violations before commit.

## Architecture Tests

Each scaffolded module includes architecture tests:

```csharp
// tests/KoreForge.RestApi.Architecture.NedCase.Tests/LayeringTests.cs
[Fact]
public void External_Must_Not_Reference_Domain()
{
    Types.InAssembly(ExternalAssembly)
        .ShouldNot().HaveDependencyOn(DomainAssembly.FullName)
        .Check(result => Assert.True(result.IsSuccessful, result.FailingTypeNames));
}
```

## Checklist

- [ ] `new-api.ps1` used to scaffold — never create layers manually
- [ ] All External interfaces and DTOs are `internal`
- [ ] All Refit methods return `Task<ApiResponse<T>>`
- [ ] All Refit methods have `CancellationToken ct = default` as last parameter
- [ ] No Polly/retry in External layer
- [ ] Domain maps `ApiResponse<T>` → domain model — never leaks External DTOs upward
- [ ] Internal controllers return `ProblemDetails` on error with correlation id
- [ ] `dotnet build -warnaserror` passes with zero analyzer violations
- [ ] Architecture tests in separate test project pass
