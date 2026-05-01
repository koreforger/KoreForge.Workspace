---
name: koreforge-docker-infra
description: "Use when working on KoreForge Docker development infrastructure, docker compose scripts, SQL bootstrap, Kafka readiness, docker-up/down/reset/status, or infrastructure readiness problems."
---

# KoreForge Docker Infrastructure

Use this skill when adding, fixing, or diagnosing local Docker infrastructure.

## Ground Rules

- Fix readiness and bootstrap ordering at the infrastructure layer.
- Do not add production-code retries to mask Docker readiness problems.
- Start, stop, reset, and inspect infrastructure through scripts.
- SQL bootstrap scripts must fail fast on SQL errors.
- Do not commit container state, database files, logs, Kafka data, or checkpoints.

## Inspect First

1. `docs/development/docker.md`.
2. Root `scr/docker-up.ps1`, `scr/docker-down.ps1`, `scr/docker-reset.ps1`, `scr/docker-status.ps1`.
3. `docker/docker-compose.yml`.
4. `docker/scripts/` and `docker/sql/` if present.
5. App-specific scripts in Event repos.

## Standard Commands

```powershell
pwsh -File scr/docker-up.ps1
pwsh -File scr/docker-status.ps1
pwsh -File scr/docker-reset.ps1
pwsh -File scr/docker-down.ps1
```

Use the configured container CLI for manual commands only after checking the workspace/container configuration.

## SQL Bootstrap Rules

- Use `sqlcmd -b` or equivalent fail-fast behavior.
- Use `SET QUOTED_IDENTIFIER ON` before filtered indexes and affected `MERGE` statements.
- Use null-safe predicates when matching nullable scope columns.
- Make bootstrap idempotent.

## Kafka/Redpanda Rules

- Scripts should wait for broker readiness before starting dependent apps or tests.
- Topic creation should be idempotent.
- Reset scripts should make state predictable.

## Validation

- `docker-up` completes only when services are ready.
- `docker-status` reports useful health details.
- `docker-reset` leaves SQL/Kafka in a known state.
- Event integration tests can run after setup without manual compose steps.
- Generated state remains ignored and untracked.
