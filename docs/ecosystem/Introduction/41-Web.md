# KoreForge.Web

| | |
|---|---|
| **Package** | `KoreForge.Web.RestApi.Abstractions`, `KoreForge.Web.RestApi.Observability`, `KoreForge.Web.RestApi.Persistence`, `KoreForge.Web.Authorization` |
| **Namespace** | `KoreForge.Web.*` |
| **Source** | `KoreForge.Web/src/` |
| **Tests** | `KoreForge.Web/tst/` |
| **Dependencies** | ASP.NET Core, KoreForge.Metrics, KoreForge.Logging |

## Problem

Building production REST APIs in ASP.NET Core requires repeated scaffolding: response envelopes, error handling, ProblemDetails formatting, audit logging, authorization middleware, health checks, observability wiring, and HTTP client configuration. Each team solves these differently, producing inconsistent APIs with varying error formats and security postures.

Integrating with external APIs introduces even more boilerplate: Refit client generation, retry policies, circuit breakers, request/response logging, and correlation ID propagation.

## Solution

KoreForge.Web provides a multi-layer REST API framework that separates concerns into discrete, testable packages:

- **Abstractions** — Shared contracts, options, and extension points common to all layers.
- **Observability** — Structured logging, metrics, and correlation ID propagation for HTTP traffic.
- **Persistence** — API call audit persistence using `ApiCallAudit` records (ApiName, Operation, Direction, StatusCode, CorrelationId, RequestPayload, ResponsePayload).
- **Authorization** — Role semantics engine with policy-based authorization and tenant isolation.
- **Host** — Internal Web host for multi-API aggregation behind a single entry point.

## Compromises

- The layer model (External → Domain → Internal → Client) is opinionated. Simpler APIs may find the four-layer structure excessive.
- OpenAPI-first external integration requires an `openapi.json` per provider. If no spec exists, you must write one.
- Roslyn analyzers enforce layer boundaries at compile time. This catches violations early but adds initial learning curve.

## Architecture

The framework follows a four-layer pattern for each API integration:

```
┌────────────────────────────────────────────────────────────────┐
│  Client SDK         →  I<Api>Client (consumer-facing)          │
│  Internal Endpoints →  /api/<name>/...   (minimal APIs)        │
│  Domain Layer       →  Use cases, orchestration, audit          │
│  External Layer     →  Refit proxy, DTO mapping, hooks          │
└────────────────────────────────────────────────────────────────┘
```

## DI Registration

Each layer follows a consistent registration pattern:

```csharp
// External: transport + hooks
services.Add<ApiName>External(configuration);

// Domain: orchestration + audit
services.Add<ApiName>Domain();

// Internal: HTTP endpoints
app.Map<ApiName>Endpoints();

// Client SDK: consumer-side
services.Add<ApiName>Client(configuration);
```

## Key Types

### ApiCallAudit

Captures every cross-boundary HTTP call:

```csharp
public record ApiCallAudit
{
    public string ApiName { get; init; }
    public string Operation { get; init; }
    public string Direction { get; init; }     // Inbound | Outbound
    public int StatusCode { get; init; }
    public string CorrelationId { get; init; }
    public string? RequestPayload { get; init; }
    public string? ResponsePayload { get; init; }
}
```

### ApiCallHooksDelegatingHandler

Automatically captures raw request/response JSON for audit and debugging. Registered transparently by the External layer.

### ProblemDetails

All errors return RFC 7807 ProblemDetails with a correlation ID:

```json
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Not Found",
  "status": 404,
  "detail": "Order 12345 not found",
  "instance": "/api/orders/12345",
  "correlationId": "abc-123"
}
```

### Authorization & Row-Level Filtering

```csharp
// Register row-level filter for multi-tenant isolation
services.AddScoped<IRowLevelFilterProvider<Order>, TenantOrderFilter>();
```

## Sub-Packages

| Package | Description |
|---|---|
| `KoreForge.RestApi.Common.Abstractions` | Shared contracts, options |
| `KoreForge.RestApi.Common.Analyzers` | Roslyn rules enforcing layer separation |
| `KoreForge.RestApi.Common.Observability` | Observability helpers |
| `KoreForge.RestApi.Common.Persistence` | Audit persistence |
| `KoreForge.RestApi.Host.Internal` | Internal API host |
| `KoreForge.Web.Authorization` | Role semantics & authorization |
| `KoreForge.Web.HealthChecks` | Health check endpoints |

## See Also

- `KoreForge.Web/doc/3. Specification.md` — Full technical specification
- `KoreForge.Web/doc/versioning-guide.md` — API versioning guide
