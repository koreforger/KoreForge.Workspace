# KoreForge.Templates

| | |
|---|---|
| **Package** | `KoreForge.Templates` |
| **Source** | `KoreForge.Templates/` |
| **Dependencies** | .NET SDK template engine |

## Problem

Starting a new KoreForge project requires recreating the same solution structure, wiring up DI, adding standard scripts, configuring build properties, and importing the correct NuGet packages. This setup takes time and is error-prone — teams forget scripts, misconfigure settings, or skip observability wiring.

## Solution

KoreForge.Templates is a NuGet template pack that provides `dotnet new` scaffolding. Each template produces a complete, buildable solution with all KoreForge conventions pre-applied: bin scripts, Directory.Build.props, Central Package Management, DI registration, structured logging, health checks, and observability.

## Installation

```powershell
dotnet new install KoreForge.Templates
```

## Available Templates

| Short Name | Type | Description |
|---|---|---|
| `kf-kafka-processor` | Solution | Kafka consumer with Vue 3 dashboard, SignalR metrics, SQL live-reload settings, structured logging, health checks |
| `kf-data` | Solution | EF Core data library with database-first scaffolding, partial DbContext, options, and DI registration |
| `kf-odata` | Solution | OData controller library with Roslyn source-generated CRUD controllers from a DbContext |

---

## kf-kafka-processor

Creates a full Kafka consumer application with dashboard.

```powershell
dotnet new kf-kafka-processor -n MyApp --KafkaTopic orders --DatabaseName OrderDb
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Application name (replaces `EventProcessor` throughout) |
| `--KafkaTopic` | `transactions` | Kafka topic to consume |
| `--DatabaseName` | `FraudEngine` | SQL Server database name |

### What You Get

- ASP.NET Core host with Kafka consumer pipeline
- Vue 3 SPA dashboard with live SignalR metrics
- SQL Server-backed live-reload settings (KoreForge.Settings)
- Structured logging with source-generated event IDs
- Docker Compose for local dev (Redpanda + SQL Edge)
- Health check endpoints
- Standard bin scripts

---

## kf-data

Creates an EF Core data library using database-first scaffolding.

```powershell
dotnet new kf-data -n MyCompany.Data.Staff --DatabaseShort Staff
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Project name and namespace |
| `--DatabaseShort` | `Alerts` | Short name for DbContext, options, methods (e.g. `Staff` → `StaffDbContext`) |

### Post-Scaffold Steps

1. Edit `config/scaffold-config.json` with your connection string and schemas
2. Run `./scr/scaffold-db.ps1` to generate entity classes from the database

---

## kf-odata

Creates an OData controller library with source-generated CRUD endpoints.

```powershell
dotnet new kf-odata -n MyCompany.OData.Staff --DatabaseShort Staff --DataNamespace MyCompany.Data.Staff
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-n` | _(required)_ | Project name and namespace |
| `--DatabaseShort` | `Alerts` | Short name matching Data library (e.g. `Staff` → `StaffDbContext`) |
| `--DataNamespace` | `KF.Data.Alerts` | Full namespace of the Data library where the DbContext lives |

### Post-Scaffold Steps

1. Add a `ProjectReference` to your Data library in the `.csproj`
2. Build to trigger source generation
3. Run `./scr/scaffold-odata.ps1` if additional scaffolding is needed

---

## Template Sources

| Template | Source Location |
|---|---|
| `kf-kafka-processor` | `apps/EventProcessor/` — the live app IS the template (golden master) |
| `kf-data` | `templates/kf-data/` — standalone template archetype |
| `kf-odata` | `templates/kf-odata/` — standalone template archetype |

## Local Development

```powershell
# Install templates from source
./scr/install-local.ps1

# Test 
dotnet new kf-data -n TestData --DatabaseShort Test -o /tmp/TestData

# Uninstall
./scr/uninstall-local.ps1

# Pack for release
./scr/build-pack.ps1    # → artifacts/KoreForge.Templates.<version>.nupkg
```

## See Also

- `KoreForge.Templates/README.md` — Full README
- `KoreForge.Templates/bin/` — Build and install scripts


