---
name: koreforge-web-healthchecks
description: "Use when wiring health endpoints in a KoreForge ASP.NET app via KoreForge.Web.HealthChecks: MapKfHealthEndpoints + HealthTags (Ready, Live, Sql, Kafka). Keywords: MapKfHealthEndpoints, HealthTags, /health, /health/ready, /health/live, IHealthChecksBuilder, readiness probe, liveness probe."
---

# KoreForge.Web.HealthChecks Skill

## When to use

- Adding `/health`, `/health/ready`, or `/health/live` endpoints to an ASP.NET host.
- Registering an `IHealthCheck` and choosing the right tags so it surfaces on the right endpoint.
- Configuring Kubernetes readiness/liveness probes.

## Endpoints (fixed convention)

`MapKfHealthEndpoints` exposes exactly three endpoints — do not invent variations:

| Route | Predicate | Use as |
|---|---|---|
| `/health` | all checks | Full operational dashboard. |
| `/health/ready` | tag `HealthTags.Ready` | Kubernetes readiness probe. |
| `/health/live` | tag `HealthTags.Live` | Kubernetes liveness probe. Cheap, no I/O. |

## Tag constants

`HealthTags` defines the only tags the routing recognizes:

| Constant | Value | Meaning |
|---|---|---|
| `Ready` | `"ready"` | Must pass for the app to serve traffic. |
| `Live` | `"live"` | Must pass for the process to be considered alive. |
| `Sql` | `"sql"` | SQL connectivity / settings DB checks. |
| `Kafka` | `"kafka"` | Kafka producer/consumer connectivity. |

`Sql` and `Kafka` are descriptive only — they do **not** affect routing. Tag with `Ready` or `Live` (often both) to control which endpoint exposes the check.

## Wiring

```csharp
using KoreForge.Web.HealthChecks;

builder.Services.AddHealthChecks()
    // Liveness: fast and dependency-free.
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: new[] { HealthTags.Live })

    // Readiness: SQL must be reachable before we accept traffic.
    .AddSqlServer(
        connectionString: cfg.GetConnectionString("Settings")!,
        name: "settings-db",
        tags: new[] { HealthTags.Ready, HealthTags.Sql })

    // Readiness: Kafka admin client must respond.
    .AddCheck<KafkaReadinessCheck>(
        name: "kafka",
        tags: new[] { HealthTags.Ready, HealthTags.Kafka });

var app = builder.Build();
app.MapKfHealthEndpoints();
```

## Tagging rules

- A check with **no tag** appears only on `/health`.
- A check tagged `Ready` only → only on `/health` and `/health/ready`.
- A check tagged `Live` only → only on `/health` and `/health/live`.
- Tag both when the check is cheap and meaningful for liveness too.
- Liveness checks must not call SQL, Kafka, HTTP, or anything that can hang. Use `Live` only for in-process state (e.g. a `BackgroundService` heartbeat flag).

## Pitfalls

- Forgetting to tag a SQL/Kafka check at all → it never blocks readiness; the pod will be marked Ready while the dependency is down.
- Tagging a slow external call with `Live` → flapping liveness restarts the pod under load. Reserve `Live` for trivial checks.
- Calling `MapKfHealthEndpoints` before `app.Build()` (typo) — it is an `IEndpointRouteBuilder` extension, call after `builder.Build()`.
- Building your own `MapHealthChecks(...)` block beside `MapKfHealthEndpoints()` — duplicates routes. Pick one.

## Checklist

- [ ] `app.MapKfHealthEndpoints()` called once after `builder.Build()`.
- [ ] Every external dependency check tagged with `HealthTags.Ready` (and the descriptive tag `Sql`/`Kafka` if applicable).
- [ ] Every liveness check tagged with `HealthTags.Live` and performs no I/O.
- [ ] Kubernetes `readinessProbe.httpGet.path` = `/health/ready`; `livenessProbe.httpGet.path` = `/health/live`.
