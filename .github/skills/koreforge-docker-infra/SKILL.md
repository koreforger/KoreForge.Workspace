---
name: koreforge-docker-infra
description: "Use when starting/stopping the local Docker development stack, adding services to docker/docker-compose.yml, fixing readiness/bootstrap problems, writing SQL or Kafka init scripts, or running tests/apps that need Redpanda or Azure SQL Edge."
---

# KoreForge Docker Infrastructure Skill

## When to use

- Spinning the workspace dev stack up/down (`docker-up.ps1`, `docker-down.ps1`, `docker-status.ps1`, `docker-reset.ps1`).
- Adding or modifying services in [docker/docker-compose.yml](docker/docker-compose.yml).
- Adding SQL bootstrap files under [docker/sql/](docker/sql).
- Adding/repairing readiness/wait-for scripts under [docker/scripts/](docker/scripts).
- Diagnosing "Kafka isn't there" / "SQL refused connection" failures from Event apps or integration tests.

## Ground rules (do not violate)

- **Infra-first discipline.** Fix container ordering, healthchecks, and bootstrap scripts. Never add C# retries / `Polly` / `WaitForXxx` to mask a Docker readiness gap.
- **Bootstrap scripts must fail fast.** SQL scripts use `sqlcmd -b`; PowerShell uses `$ErrorActionPreference = 'Stop'` + `if ($LASTEXITCODE -ne 0) { throw }`.
- **No state in git.** Volumes (`redpanda_data`, `sqledge_data`), generated `*.log`, dump files, checkpoint files — all ignored.
- **Idempotent.** Running `docker-up.ps1` twice, or re-running an init SQL script, must be safe.

## Stack as it ships

[docker/docker-compose.yml](docker/docker-compose.yml) defines three services on the `streamnet` bridge network:

| Service | Image | Host port | Notes |
|---|---|---|---|
| `redpanda` | `redpandadata/redpanda:v24.1.2` | `29092` (Kafka), `9644` (admin) | Healthcheck: `rpk cluster info`. External advertised address is `localhost:29092`. |
| `sqledge` | `mcr.microsoft.com/azure-sql-edge:latest` | `14334` → 1433 | SA password `Streaming!Pass123`. Mounts `./sql` to `/docker-entrypoint-initdb.d`. Healthcheck: `sqlcmd … SELECT 1`. |
| `console` | `redpandadata/console:v2.4.5` | `8081` → 8080 | Kafka UI; depends on `redpanda` healthy. |

Apps connect via:

- Kafka bootstrap: `localhost:29092`
- SQL: `Server=localhost,14334;User Id=sa;Password=Streaming!Pass123;TrustServerCertificate=True`

Change those values nowhere except [docker/docker-compose.yml](docker/docker-compose.yml) and the appsettings of consumers.

## Workspace scripts (root [scr/](scr))

| Script | What it does |
|---|---|
| [scr/docker-up.ps1](scr/docker-up.ps1) | `docker compose up -d` then runs [docker/scripts/configure-infra.ps1](docker/scripts/configure-infra.ps1) if present (post-up topic creation, schema seeding). |
| [scr/docker-status.ps1](scr/docker-status.ps1) | `docker compose ps` — shows container + health status. |
| [scr/docker-down.ps1](scr/docker-down.ps1) | Stops containers, preserves volumes. |
| [scr/docker-reset.ps1](scr/docker-reset.ps1) | Stops containers and **wipes volumes** — use to get back to a known empty state. |

All four are also surfaced in `builder.ps1` under the `── SYSTEM ──` group.

## Adding a service

1. Add the service block to [docker/docker-compose.yml](docker/docker-compose.yml). Always include a `healthcheck`.
2. If it depends on another service being **ready** (not just started), use `depends_on: { other: { condition: service_healthy } }`.
3. If it needs post-start setup (topic creation, schema seeding, user creation), put the logic in [docker/scripts/configure-infra.ps1](docker/scripts/configure-infra.ps1) — it runs once after `docker compose up -d`.
4. If it needs SQL bootstrap, drop a `*.sql` file in [docker/sql/](docker/sql); Azure SQL Edge auto-runs files in `/docker-entrypoint-initdb.d` on first start. Use `init.sql` for schema, `seed.sql` for data — keep them separate.
5. Bind a non-default host port (e.g. `14334:1433`, `29092:9092`) — never the default. Avoids collisions with locally installed SQL Server / Kafka.
6. Add the host port and credentials to [docker/docker-compose.yml](docker/docker-compose.yml) comments and to any consumer's `appsettings.Development.json`.

## SQL bootstrap rules

- First line of every script: `SET QUOTED_IDENTIFIER ON;` and `SET NOCOUNT ON;`.
- Use `IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'…') CREATE DATABASE …` — never bare `CREATE`.
- Do not use `MERGE` against tables where `NULL` is a meaningful value without an explicit null-safe predicate (`((target.col = source.col) OR (target.col IS NULL AND source.col IS NULL))`).
- Filtered indexes require `SET QUOTED_IDENTIFIER ON` at the session that creates them.
- Run scripts via `sqlcmd -b -S localhost,14334 -U sa -P 'Streaming!Pass123' -i file.sql` — `-b` makes errors return non-zero so the wrapping PowerShell can throw.

## Kafka / Redpanda rules

- Topic creation goes in [docker/scripts/configure-infra.ps1](docker/scripts/configure-infra.ps1) using `rpk topic create <name> --partitions N -p cleanup.policy=…`. Make it idempotent (`rpk topic create … || true` is fine; capture `$LASTEXITCODE` and only treat real failures as errors).
- Wait for broker before producing: `rpk cluster info` returns 0 only when the broker is up.
- Reset = stop containers + remove `redpanda_data` volume; never try to "purge" via `rpk` for tests.

## Running apps and tests against the stack

- Integration tests assume the stack is up. Test runners do **not** call `docker compose up`. Run `scr/docker-up.ps1` first (CI does this in a setup step).
- Each Event app's `appsettings.Development.json` must point to `localhost:29092` and `localhost,14334`. If you change the host port in compose, update appsettings in lockstep.
- For a clean test run: `scr/docker-reset.ps1` then `scr/docker-up.ps1` then the test/build script.

## Diagnosis playbook

| Symptom | First check |
|---|---|
| Producer fails with "no metadata for topic" | Topic creation step in `configure-infra.ps1` failed silently, or test ran before `docker-up`. |
| `Login failed for user 'sa'` | Wrong port (1433 vs 14334) or wrong password. SQL Edge takes ~30s on first start — `docker-status.ps1` should show `(healthy)`. |
| `Connection refused` on 29092 | Container is up but not yet healthy. Wait for healthcheck or check `docker logs streaming-redpanda`. |
| Test passes locally, fails in CI | CI is missing the `docker-up` step, or healthcheck timeout is too short for CI's slower disk. |
| State carrying across runs | Add a `docker-reset` step before the affected test class; or fix the test to clean up its own topics/tables. |

## Validation

```powershell
pwsh -File scr/docker-up.ps1
pwsh -File scr/docker-status.ps1   # all services should report (healthy)
# run app or test
pwsh -File scr/docker-reset.ps1    # back to empty
```
