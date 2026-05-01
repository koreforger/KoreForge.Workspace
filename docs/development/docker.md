# Docker Development

Docker infrastructure is part of the developer experience. It should be quick to start, stop, reset, and diagnose.

## Current Source

The existing Docker composition was copied from the original workspace into `docker/` only if/when it becomes part of the new workspace shell. Package- or app-specific Docker scripts should remain close to the repo that owns them.

## Rules

1. Prefer infrastructure readiness checks over application runtime retries.
2. Start dependencies through scripts, not manual compose commands.
3. SQL bootstrap scripts must fail fast when SQL commands fail.
4. Do not commit runtime database files, logs, FASTER checkpoints, Kafka data, or generated container state.
5. Document every port, username, password source, and reset command.

## Recommended Commands

Workspace-level scripts should eventually expose:

```powershell
.\scr\docker-up.ps1
.\scr\docker-down.ps1
.\scr\docker-reset.ps1
.\scr\docker-status.ps1
```

App-level scripts can wrap these when an app has extra setup.

## Expected Services

At minimum, Event app development usually needs:

| Service | Purpose |
|---|---|
| SQL Server | Settings, Scripts, app metadata, Event data. |
| Kafka/Redpanda | Event ingestion and output topics. |
| Optional monitoring registry | Monitoring shell registry and heartbeat target. |

## Next Cleanup

Bring the original `docker/docker-compose.yml`, SQL bootstrap scripts, and app-specific startup scripts into this standard, then wire them into builder as system scripts.
