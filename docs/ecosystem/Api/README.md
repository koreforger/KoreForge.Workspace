# API Reference Documentation

This folder contains generated API reference documentation for each `KoreForge.*` package. The files are produced from the XML documentation embedded in each NuGet package and converted to LLM-readable Markdown.

---

## Package Reference Files

| File | Package | Contents |
|------|---------|----------|
| [KoreForge.Time.md](KoreForge.Time.md) | `KoreForge.Time` | `ISystemClock`, `VirtualSystemClock`, clock singletons |
| [KoreForge.Logging.md](KoreForge.Logging.md) | `KoreForge.Logging` | `LogEventSourceAttribute`, generated logger surface |
| [KoreForge.Metrics.md](KoreForge.Metrics.md) | `KoreForge.Metrics` | `IOperationMonitor`, `OperationScope`, `MonitoringSnapshot` |
| [KoreForge.Processing.md](KoreForge.Processing.md) | `KoreForge.Processing` | `Pipeline`, `Flow`, all steps and stage abstractions |
| [KoreForge.AppLifecycle.md](KoreForge.AppLifecycle.md) | `KoreForge.AppLifecycle` | `ILifecycleFlow`, `ApplicationLifecycleOptions`, events |
| [KoreForge.Kafka.md](KoreForge.Kafka.md) | `KoreForge.Kafka` | Consumer/Producer hosts, `IProducerBuffer`, policies |
| [KoreForge.Jex.md](KoreForge.Jex.md) | `KoreForge.Jex` | `Jex` class, transform methods |
| [KoreForge.Web.md](KoreForge.Web.md) | `KoreForge.Web` | Authorization, endpoint builder, `ICurrentUser` |
| [KoreForge.Settings.md](KoreForge.Settings.md) | `KoreForge.Settings` | `ISettingsService`, `IHistoryService`, `KoreForgeSettingsOptions` |
| [KoreForge.Data.md](KoreForge.Data.md) | `KoreForge.Data` | `AlertsDbContext`, entity model, registration |
| [KoreForge.OData.md](KoreForge.OData.md) | `KoreForge.OData` | Source generator, attributes, base controller, security |
| [KoreForge.Json.md](KoreForge.Json.md) | `KoreForge.Json` | `JsonMaterializer`, `RootPropertyClassifier` |

---

## Version Manifest

The file [`manifest.json`](manifest.json) records the package version each API reference file was generated from:

```json
{
    "generated": "2026-03-15T10:00:00Z",
    "packages": [
        { "package": "KoreForge.Time",        "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Logging",     "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Metrics",     "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Processing",  "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.AppLifecycle","version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Kafka",       "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Jex",         "version": "1.0.0", "source": "nupkg" },
        { "package": "KoreForge.Web",         "version": "1.0.0", "source": "nupkg" }
    ]
}
```

Run `scr/collect-api-docs.ps1` to regenerate all files and update the manifest.

---

## How XML Docs Are Generated

### Step 1 — Enable XML generation in each project

Each library's `Directory.Build.props` includes:

```xml
<GenerateDocumentationFile>true</GenerateDocumentationFile>
```

The .NET SDK writes `{AssemblyName}.xml` alongside the DLL during build.

### Step 2 — Include XML files in NuGet packages

**Single-assembly packages** (Time, AppLifecycle, Jex, etc.): The XML file is automatically included in the NuGet package when `GenerateDocumentationFile=true` is set on the packable project.

**Multi-assembly bundler packages** (Processing, Kafka, Logging): The bundler `.csproj` uses `None Include=...` to explicitly include each sub-assembly's XML file alongside the DLL:

```xml
<!-- In KoreForge.Processing.csproj (bundler) -->
<ItemGroup>
  <ProcessingAssemblies Include="$(MSBuildThisFileDirectory)..\KoreForge.Processing.Pipelines\bin\$(Configuration)\net10.0\KoreForge.Processing.Pipelines.dll" />
  <ProcessingAssemblies Include="$(MSBuildThisFileDirectory)..\KoreForge.Processing.Pipelines\bin\$(Configuration)\net10.0\KoreForge.Processing.Pipelines.xml" />
  <!-- ... repeat for each sub-assembly ... -->
</ItemGroup>
```

### Step 3 — Collect from NuGet packages

`scr/collect-api-docs.ps1` (in this repository) runs after each library publishes:

1. Locates each library's latest `.nupkg` in its `artifacts/` folder (or downloads from the NuGet feed)
2. Expands the `.nupkg` (it is a zip file)
3. Extracts `lib/net10.0/*.xml` files
4. Copies them to `doc/Api/{PackageName}/`
5. Writes `doc/Api/manifest.json` recording the package version alongside each file

### Step 4 — Convert to Markdown

`scr/generate-api-markdown.ps1` reads each XML file and produces the Markdown reference files in this folder. The XML format is:

```xml
<doc>
  <assembly><name>KoreForge.Time</name></assembly>
  <members>
    <member name="T:KoreForge.Time.ISystemClock">
      <summary>Abstracts the system clock...</summary>
    </member>
    <member name="P:KoreForge.Time.ISystemClock.UtcNow">
      <summary>Returns the current UTC time.</summary>
    </member>
  </members>
</doc>
```

The generator groups by type (`T:`), then lists properties (`P:`), methods (`M:`), and fields (`F:`), producing a Markdown section per type.

### Step 5 — Version tracking

The `manifest.json` file permanently links each Markdown reference file to the exact NuGet package version it was generated from. When reviewing LLM-generated output, you can verify:

> "The LLM read `KoreForge.Time.md` which was generated from `KoreForge.Time 1.0.0`. The current deployed version is also `1.0.0`. The docs are accurate."

---

## Keeping Docs in Sync

After releasing any `KoreForge.*` package:

```powershell
# From KoreForge.Main root
.\bin\collect-api-docs.ps1     # extract XMLs from latest packages → doc/Api/xml/
.\bin\generate-api-markdown.ps1 # convert XMLs → Markdown reference files
git add doc/Api/
git commit -m "docs: regenerate API reference for KoreForge.Kafka 1.1.0"
```

The commit message should include the package and version that triggered the refresh.

---

## For LLMs

When using these files to understand a KoreForge API:

1. Read `manifest.json` first — verify the version matches what your code targets
2. Read the package's Markdown file for type signatures and parameter docs
3. Cross-reference with [../Introduction/](../Introduction/) for usage patterns and design context
4. If a type is not in the Markdown file, it is internal — do not attempt to use it
