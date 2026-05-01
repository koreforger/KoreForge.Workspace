# Tools and Scripts Reference

Every KoreForge repository ships with a standard set of automation scripts in its `scr/` directory. These scripts are designed to be run from any working directory — they resolve paths relative to the repository root automatically.

The workspace also contains top-level scripts for cross-repository operations.

---

## Per-Repository Scripts

These scripts exist in every library repository's `scr/` folder. Replace `{Solution}` with the repo name (e.g. `KoreForge.Kafka.slnx`).

### build-clean.ps1

**NAME**
    build-clean — Remove all build artifacts

**SYNOPSIS**
```powershell
.\scr\build-clean.ps1
```

**DESCRIPTION**
    Runs `dotnet clean` on the solution and removes the `out/` directory.

---

### build-rebuild.ps1

**NAME**
    build-rebuild — Force-rebuild the solution

**SYNOPSIS**
```powershell
.\scr\build-rebuild.ps1 [-Configuration <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Release` | Build configuration |

**DESCRIPTION**
    Runs `dotnet build --force` on the solution.

---

### build-test.ps1

**NAME**
    build-test — Build and run all tests

**SYNOPSIS**
```powershell
.\scr\build-test.ps1 [-Configuration <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Debug` | Build configuration |

**DESCRIPTION**
    Builds the solution, runs all tests, and writes an HTML test report to `out/TestResults/TestResults.html`.

---

### build-test-codecoverage.ps1

**NAME**
    build-test-codecoverage — Build, test, and generate code coverage report

**SYNOPSIS**
```powershell
.\scr\build-test-codecoverage.ps1 [-Configuration <String>] [-Open]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-Configuration` | `Debug` | Build configuration |
| `-Open` | — | Open the HTML report in the default browser |

**DESCRIPTION**
    Builds the solution, runs tests with `XPlat Code Coverage` collection using `coverlet.runsettings`, then generates an HTML coverage report via ReportGenerator at `out/TestResults/coverage/index.html`.

---

### build-pack.ps1

**NAME**
    build-pack — Pack NuGet packages

**SYNOPSIS**
```powershell
.\scr\build-pack.ps1 [-Configuration <String>]
```

**DESCRIPTION**
    Runs `dotnet pack` on the solution. Output goes to the `artifacts/` directory. Not all repos include this script — some rely on CI/CD for packing.

---

### git-push.ps1

**NAME**
    git-push — Stage, commit, and push all changes

**SYNOPSIS**
```powershell
.\scr\git-push.ps1 -Message <String>
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Message` | Yes | Commit message |

**DESCRIPTION**
    Runs `git add -A`, `git commit -m`, and `git push` from the repository root.

---

### git-push-nuget.ps1

**NAME**
    git-push-nuget — Tag and push a release version

**SYNOPSIS**
```powershell
.\scr\git-push-nuget.ps1 -Version <String> [-Note <String>] [-TagOnly] [-Force]
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Version` | Yes | Semantic version (e.g. `0.0.6-alpha`) |
| `-Note` | No | Optional release note / commit message |
| `-TagOnly` | No | Skip committing — only create and push the tag |
| `-Force` | No | Re-create the tag if it already exists |

**DESCRIPTION**
    Creates a git tag in the format `{Prefix}/v{Version}` (e.g. `Kafka/v0.0.6-alpha`), optionally committing and pushing changes first. The tag triggers the GitHub Actions Trusted Publishing workflow.

---

### git-create-repo.ps1

**NAME**
    git-create-repo — Initialize and create a GitHub repository

**SYNOPSIS**
```powershell
.\scr\git-create-repo.ps1
```

**DESCRIPTION**
    Initializes the directory as a git repo (if needed), creates a public GitHub repository under `koreforger/{RepoName}`, and pushes the initial commit. Requires the GitHub CLI (`gh`).

---

### github-set-nuget-secret.ps1

**NAME**
    github-set-nuget-secret — Set the NUGET_API_KEY secret on the GitHub repository

**SYNOPSIS**
```powershell
.\bin\github-set-nuget-secret.ps1 [-ApiKey <String>]
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-ApiKey` | No | NuGet API key. If omitted, prompts interactively (masked input) |

**DESCRIPTION**
    Sets the `NUGET_API_KEY` repository secret via `gh secret set`. Used by the Trusted Publishing workflow.

---

## Workspace-Level Scripts

Located in the top-level `scr/` directory.

### pack-all.ps1

**NAME**
    pack-all — Pack all KoreForge NuGet packages

**SYNOPSIS**
```powershell
.\scr\pack-all.ps1 -Version <String>
```

**PARAMETERS**
| Parameter | Required | Description |
|---|---|---|
| `-Version` | Yes | Version to stamp on all packages (e.g. `0.0.6-alpha`) |

**DESCRIPTION**
    Iterates all library repositories in dependency order (leaves first), runs `dotnet pack` with the specified version override, then packs template repos separately. Produces `.nupkg` files in each repo's `artifacts/` directory.

**Dependency Order:**
KoreForge.Time → KoreForge.Json → KoreForge.Data → KoreForge.OData → KoreForge.Logging → KoreForge.Logging.Serilog → KoreForge.Jex → KoreForge.AppLifecycle → KoreForge.Metrics → KoreForge.Metrics.AspNet → KoreForge.Processing → KoreForge.Settings → KoreForge.Web → KoreForge.Kafka → KoreForge.Templates

---

### create-all-repos.ps1

**NAME**
    create-all-repos — Create GitHub repositories for all projects

**SYNOPSIS**
```powershell
.\scr\create-all-repos.ps1
```

**DESCRIPTION**
    Iterates all library directories, runs each repo's `git-create-repo.ps1` to create the corresponding GitHub repository under `koreforger/`.

---

### zip-workspace.ps1

**NAME**
    zip-workspace — Archive the workspace for backup or sharing

**SYNOPSIS**
```powershell
.\scr\zip-workspace.ps1
```

**DESCRIPTION**
    Creates a zip archive of the entire KoreForge workspace, excluding build artifacts and generated files.

---

### Export-documentation.ps1

**NAME**
    Export-documentation — Generate combined documentation file

**SYNOPSIS**
```powershell
.\KoreForge.Main\scr\Export-documentation.ps1 [-OutputFile <String>]
```

**PARAMETERS**
| Parameter | Default | Description |
|---|---|---|
| `-OutputFile` | `KoreForge-Documentation.md` | Output file path |

**DESCRIPTION**
    Concatenates all markdown files from `doc/Introduction/` (sorted by filename) then `doc/Api/` (alphabetical) into a single combined documentation file. Re-running always picks up newly added docs.

---

## Docker Scripts (Kafka)

Located in `KoreForge.Kafka/samples/docker/`.

### up.ps1

Starts the local Kafka development environment (Redpanda on `localhost:29092`, Azure SQL Edge on `localhost:14333`), waits for services to be healthy, and runs configuration scripts.

### down.ps1

Stops and removes all Docker containers for the local dev environment.

---

## Template Scripts

Located in `KoreForge.Templates/bin/`.

### install-local.ps1

Installs all templates from source directories for local development testing.

### uninstall-local.ps1

Removes locally-installed template packages.

### pack.ps1

Packs the templates into `artifacts/KoreForge.Templates.<version>.nupkg`.

---

## NuGet Integration Test Scripts

Located in `KF.Nuget.Integration.Tests/scr/`.

### Build-Integration.ps1

Builds the integration test project against published NuGet packages (not local source).

### Clean-Integration.ps1

Cleans integration test build artifacts and NuGet caches.

### Install-Packages-Integration.ps1

Installs specific versions of KoreForge packages into the integration test project.

---

## CLI Tools

| Tool | Package | Description |
|---|---|---|
| `kf-settings` | `KoreForge.Settings.Cli` | Manage SQL-backed settings: list, get, set, delete, history, rollback, export, import |
| `jex` | `KF.Jex.Cli` | Evaluate JEX expressions from the command line, pipe JSON, use as a build/CI tool |

Install globally:

```bash
dotnet tool install -g KoreForge.Settings.Cli
dotnet tool install -g KF.Jex.Cli
```

See [50-Settings.md](50-Settings.md) and [11a-Jex-Cli.md](11a-Jex-Cli.md) for full CLI documentation.

