---
name: event-integration-testing
description: "Use when adding or fixing Event.* integration tests, stress tests, Kafka/SQL fixtures, Event.Reader durability tests, run-stress scripts, or builder-discovered Event test reports."
---

# Event Integration Testing

Use this skill for Event apps and Event-owned shared libraries that validate KoreForge in realistic runtime scenarios.

## Ground Rules

- Event code uses `Event.*` names.
- Event apps consume KoreForge through NuGet packages only.
- Do not add `ProjectReference` to KoreForge repos.
- Do not vendor KoreForge source into Event apps.
- Start and reset infrastructure through scripts.
- Prefer infrastructure readiness fixes over production runtime retries.

## Inspect First

1. The target `event/Event.*` repo.
2. Existing `scr/build-integration.ps1`, `scr/run-stress-*.ps1`, and `scr/koreforge-build.psm1`.
3. Docker docs and scripts: `docs/development/docker.md`, `scr/docker-*.ps1`, `docker/`.
4. Test categories and fixtures in the target repo.
5. Package references and local feed versions.

## Test Categories

Use clear categories when adding tests:

- Unit tests: no external infrastructure.
- Integration tests: real infrastructure or realistic app host.
- Stress tests: longer-running throughput, durability, or resource behavior.

Stress scripts should be discoverable by `builder.ps1` using the pattern:

```text
scr/run-stress-*.ps1
```

If a stress script produces HTML, print:

```text
Stress report: <absolute-or-relative-path>
```

## Workflow

1. Pack needed KoreForge packages to `artifacts/packages`.
2. Start infrastructure through Docker scripts.
3. Run Event repo tests through repo scripts.
4. Add reports under `artifacts/repos/<repo>/` or `artifacts/reports`.
5. Reset infrastructure through scripts when the test mutates durable state.

## Validation

- Event tests restore KoreForge packages from the local feed or nuget.org.
- No `ProjectReference` exists.
- Reports and logs are under root `artifacts/`.
- Builder discovers integration/stress scripts.
- Docker startup/readiness is scripted and documented.
