# KoreForge Front-End — Architecture Specification

**Status**: Draft v0.1 — design only, implementation in early stages (only `KoreForge.Scripts.Vue` has code).

This document is the workspace-level specification for the entire KoreForge front-end and the back-end components required to support it. It establishes the layering, repository boundaries, package contracts, and shared patterns that every `eco-web/*` repo and every supporting `eco-system/*` package must follow.

Per-repo specifications live in each `eco-web/<Repo>/doc/specification.md` and only describe that repo's internals. The detailed monitoring-shell DTO contracts live in [`monitoring-shell-spec.md`](monitoring-shell-spec.md).

## 1. Vision

KoreForge applications are operationally complex (pipelines, durable backlogs, Jex script sets, Kafka topics, SignalR streams). The front-end exists so an operator can answer "is it healthy?" in five seconds and "where is it backed up?" in fifteen — for **any** KoreForge application, without a per-app UI.

The front-end is **not** a per-application dashboard. It is a single shell that introspects whatever the application declares and renders exactly that. Adding a new KoreForge application requires zero front-end code.

## 2. Layering

```
┌────────────────────────────────────────────────────────────────────┐
│  Browser                                                           │
│                                                                    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  KoreForge.Monitoring.Shell  (Vue 3 SPA, deployable)       │    │
│  │                                                            │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │    │
│  │  │ @koreforge/     │  │ @koreforge/     │  │ @koreforge/ │ │    │
│  │  │ vue-scripts     │  │ jex-vue         │  │ kafka-vue   │ │    │
│  │  └─────────────────┘  └─────────────────┘  └─────────────┘ │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
                              ▲    HTTP + SignalR
                              │
┌─────────────────────────────┴──────────────────────────────────────┐
│  KoreForge Application (e.g. EventReader)                          │
│                                                                    │
│  KoreForge.Monitoring.AspNetCore  ← exposes /monitoring/* + hub    │
│  KoreForge.Monitoring.Contracts   ← shared DTO records             │
│  KoreForge.Monitoring.SignalR     ← hub + delta projection         │
│  KoreForge.Scripts                ← script CRUD endpoints          │
│  KoreForge.Jex                    ← compiler + shadow-test         │
│  KoreForge.Kafka.AdminClient      ← read-only Kafka surface        │
│  KoreForge.Metrics                ← collection                     │
└────────────────────────────────────────────────────────────────────┘
```

### Layer responsibilities

| Layer | Responsibility | Repos |
|---|---|---|
| **Shell** | Application discovery, manifest fetch, capability resolution, pipeline diagram, layout, theming, routing, connection lifecycle. | `eco-web/KoreForge.Monitoring.Shell` |
| **Component packages** | Reusable, self-contained Vue 3 component libraries. Each owns a domain (scripts, jex, kafka). Published to npm. | `eco-web/KoreForge.Scripts.Vue`, `eco-web/KoreForge.Jex.Vue`, `eco-web/KoreForge.Kafka.Vue` |
| **Back-end contracts** | DTO record types shared by every endpoint and mirrored in TypeScript by the front-end. **No logic.** | `eco-system/KoreForge.Monitoring` (`KoreForge.Monitoring.Contracts`) — and the planned `KoreForge.Jex.Contracts`, `KoreForge.Kafka.Contracts`. |
| **Back-end framework** | ASP.NET Core base controllers, capability provider interfaces, manifest assembly, hub registration. | `eco-system/KoreForge.Monitoring` (`KoreForge.Monitoring.AspNetCore`, `KoreForge.Monitoring.SignalR`) |
| **Back-end domains** | The libraries that actually do the work being monitored. | `KoreForge.Scripts`, `KoreForge.Jex`, `KoreForge.Kafka`, `KoreForge.Metrics`, `KoreForge.AppLifecycle` |

## 3. Repository Inventory

### 3.1 Front-end (eco-web)

| Repo | Type | NPM name | Purpose |
|---|---|---|---|
| `KoreForge.Monitoring.Shell` | App (private) | `@koreforge/monitoring-shell` | The deployable SPA |
| `KoreForge.Scripts.Vue` | Library | `@koreforge/vue-scripts` | Generic script CRUD + history + tester |
| `KoreForge.Jex.Vue` | Library | `@koreforge/jex-vue` | Jex authoring, shadow-testing, runtime model viewer |
| `KoreForge.Kafka.Vue` | Library | `@koreforge/kafka-vue` | Read-only Kafka topology and consumer-lag visualisation |

### 3.2 Required back-end (eco-system)

| Package | Status | Purpose |
|---|---|---|
| `KoreForge.Monitoring.Contracts` | Exists | DTOs: manifest, pipeline, metric, health, capability |
| `KoreForge.Monitoring.AspNetCore` | Exists | Endpoint base classes, capability provider interfaces, manifest assembly |
| `KoreForge.Monitoring.Registry` | Exists | Server-side registry of registered apps for multi-app discovery |
| `KoreForge.Monitoring.SignalR` | **Planned** | Hub, metric delta projection, group management |
| `KoreForge.Scripts` | Exists | Script CRUD + history + compile + test endpoints |
| `KoreForge.Jex` | Exists | Compiler, runtime model, shadow-test execution |
| `KoreForge.Kafka` + `.AdminClient` | Exists | Read-only admin façade (topic metadata, consumer lag) |
| `KoreForge.Metrics` | Exists | Operation metrics that feed the snapshot endpoint |
| `KoreForge.Jex.Contracts` | **Planned** | DTOs for Jex shadow tests and runtime-model snapshots |
| `KoreForge.Kafka.Contracts` | **Planned** | DTOs for topic, consumer-group, partition, lag |

## 4. Cross-Cutting Patterns

### 4.1 Two-layer component design

Every `eco-web/*` library exposes:

- **Composables** — pure logic, reactive state, no DOM. Used by apps that bring their own UI library.
- **Default components** — drop-in Vue components that wire the composables to Monaco/Vuetify/charts.

This is the same split established by `@koreforge/vue-scripts` and is mandatory for every other library.

### 4.2 CSS-variable theming

All components use `--kf-*` CSS custom properties for visual styling. No component depends on a specific CSS framework. The shell loads `@koreforge/vue-scripts/theme/default.css` and overrides as needed. Domain libraries (`@koreforge/jex-vue`, `@koreforge/kafka-vue`) add only domain-specific tokens (e.g. `--kf-jex-keyword-color`).

### 4.3 Manifest-driven rendering

Every back-end exposes `GET /monitoring/manifest`. The shell never hardcodes which application or capability set it is rendering. The manifest declares:

- Application identity (`applicationId`, `instanceId`, `environment`, `version`).
- Capability list — each entry has a `key`, a `component` string, an `endpoint`, and optional `config`.

The shell maps `component` strings to registered Vue components. Unknown components fall back to a generic metric panel. **Adding a new capability to an application never requires shell changes.**

### 4.4 Snapshot + delta hybrid

Every metric stream follows the same pattern:

1. Initial `GET /monitoring/metrics/snapshot` seeds full state.
2. SignalR `MetricDelta` messages (1–5s cadence) update changed values only.
3. Periodic snapshot refresh (60s) corrects any drift.

This pattern applies to metrics, health, runtime model, and consumer-group lag.

### 4.5 Self-fetching components

Library components are responsible for fetching their own data. They take an `endpoint` prop, not a list of pre-fetched records. This keeps the shell free of capability-specific orchestration.

### 4.6 Read-only by default

Front-end components do not mutate broker, topic, or partition state. The only mutations any panel performs are application-level domain mutations (e.g. saving a Jex script via `KoreForge.Scripts`). Infrastructure is observed, never altered, from the browser.

## 5. Required Back-End Endpoints

Every KoreForge application that wants to be monitored must expose at minimum:

| Endpoint | Purpose |
|---|---|
| `GET /monitoring/manifest` | Identity + declared capabilities |
| `GET /monitoring/pipeline` | Pipeline graph (or empty if not applicable) |
| `GET /monitoring/metrics/snapshot` | Full metric state |
| `GET /monitoring/health` | Health checks |
| SignalR `/monitoring/hub` | Live updates |

Per-capability endpoints are declared by the manifest and can take any path under `/monitoring/*`.

The wire formats and full DTO definitions are in [`monitoring-shell-spec.md`](monitoring-shell-spec.md) §4–5.

## 6. Cross-Repo Dependency Rules

These follow the workspace [dependency rules](../../README.md):

- The shell **only** consumes other front-end repos as **npm dependencies** from npmjs.org. No `npm link`, no `file:` references, no monorepo symlinks.
- Component libraries **never** depend on the shell. Dependencies always flow downward.
- C# `*.Contracts` packages are the boundary between back-end and front-end. The TS DTOs in each `eco-web` repo must mirror the records exactly. When a contract changes, both sides bump and re-publish.
- No front-end code imports from `eco-system/` source. Front-end consumes back-end **only** through HTTP + SignalR.

## 7. Build & Release Topology

| Concern | Approach |
|---|---|
| TypeScript build | Vite library mode for libraries, Vite app mode for the shell. |
| Versioning | Semver. Each library is independently versioned. Tag pattern `KoreForge.<Name>.Vue/v*`. |
| Publish | npm `publish-npm.yml` workflow per library, gated on `main` branch (same pattern as the C# `publish-nuget.yml` workflows). |
| Shell deployment | Static bundle; planned container image `koreforger/monitoring-shell:vX.Y.Z`. |
| CI | `ci.yml` runs typecheck + lint + test + build for every push. |

NPM workflow file naming follows the established pattern: `publish-npm.yml`, **not** `npm-publish.yml`.

## 8. Implementation Sequence

The end-to-end sequence runs back-to-front so contracts are stable before any UI consumes them.

| Phase | Work | Outcome |
|---|---|---|
| 1 | Finalise `KoreForge.Monitoring.Contracts` DTOs. Mirror in TS in each Vue repo. | Contracts frozen for v1. |
| 2 | Implement `KoreForge.Monitoring.AspNetCore` manifest, pipeline, health endpoints in EventReader. | First application monitored. |
| 3 | Implement `KoreForge.Monitoring.SignalR` hub with metric delta projection. | Live updates wired. |
| 4 | Scaffold `KoreForge.Monitoring.Shell` (Vite, Pinia, Vue Router, Vuetify). Render the pipeline from EventReader's manifest. | Pipeline diagram live with EventReader. |
| 5 | Build `@koreforge/jex-vue` (script panel, editor panel, test panel). Wire into shell registry. | Jex authoring live in the shell. |
| 6 | Build `@koreforge/kafka-vue` (consumer, lag, topic panels) backed by `KoreForge.Kafka.AdminClient` HTTP façade. | Kafka observability live. |
| 7 | EventReader-specific panels in the shell (`DurableBacklogPanel`, `ShardWorkerPanel`). | EventReader fully covered. |
| 8 | Multi-app support: `apps.json` discovery, `AppSelector`, per-app SignalR connections. | Multiple apps in one shell. |
| 9 | Polish: dark theme, connection banner, error states, mobile/tablet layout review. | v1 release candidate. |

## 9. Out of Scope

- Per-application bespoke front-ends. Everything goes through the shell.
- A web-based Jex IDE outside the shell (the [VS Code extension](../../tools/KoreForge.Jex.VSCodeExtension/) covers the standalone authoring use-case).
- Server-side rendering or Nuxt — the shell is client-only.
- Browser-side direct Kafka or SignalR-without-auth. All connections go through the application layer.
- Multi-tenant user/role administration UI.

## 10. References

| Document | Purpose |
|---|---|
| [monitoring-shell-spec.md](monitoring-shell-spec.md) | Full DTO contracts, capability registry, and SignalR message wire formats. |
| [eco-web/KoreForge.Monitoring.Shell/doc/specification.md](../../eco-web/KoreForge.Monitoring.Shell/doc/specification.md) | Per-repo spec for the shell. |
| [eco-web/KoreForge.Scripts.Vue/doc/specification.md](../../eco-web/KoreForge.Scripts.Vue/doc/specification.md) | Per-repo spec for the script library. |
| [eco-web/KoreForge.Jex.Vue/doc/specification.md](../../eco-web/KoreForge.Jex.Vue/doc/specification.md) | Per-repo spec for the Jex library. |
| [eco-web/KoreForge.Kafka.Vue/doc/specification.md](../../eco-web/KoreForge.Kafka.Vue/doc/specification.md) | Per-repo spec for the Kafka library. |
| [eco-system/KoreForge.Monitoring/doc/](../../eco-system/KoreForge.Monitoring/) | Back-end monitoring package documentation. |
