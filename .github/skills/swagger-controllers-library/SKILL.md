---
name: swagger-controllers-library
description: "Use when creating, consuming, extending, testing, or regenerating a KoreForge.SwaggerControllers-based external API library. Covers: scaffold from template, copy/patch metadata.json, run generate.ps1, customise decorator chain, InternalsVisibleTo for tests, DI registration. Keywords: SwaggerControllers, generate.ps1, metadata.json, LoggingDecorator, BusinessDecorator, PersistenceDecorator, Outcome, ExternalAuthOptions."
---

# swagger-controllers-library SKILL

## When to use

Use this skill when **any** of the following apply:

- Creating a new `Event.*` (or other) repo that wraps one or more external APIs using `KoreForge.SwaggerControllers.Abstractions`.
- Adding a new API to an existing SwaggerControllers-based library.
- Re-running `generate.ps1` after editing a `metadata.json`.
- Writing tests for an API library project.
- Debugging a broken build or missing package in a SwaggerControllers library.

Do **not** use this skill for:

- Converting a raw Swagger 2.0 file into `metadata.json` — that is the `parse-swagger` skill.
- Changing the generator itself (`generate.ps1.txt`) — that is a KoreForge.SwaggerControllers maintainer task.
- General ASP.NET Core controller testing.

---

## Concepts

| Concept | Description |
| --- | --- |
| **metadata.json** | The input to the generator. Describes one API: its namespace, operations, DTOs, and auth configuration. One file per `swaggers/<ApiName>/v<N>/` folder. |
| **Stage 1** | Converting a raw swagger into `metadata.json`. Use the `parse-swagger` skill. |
| **Stage 2** | Running `generate.ps1` to produce C# from `metadata.json`. |
| **Generated/** | Files in `src/<Project>/Generated/` — overwritten on every generator run. Never hand-edit these. |
| **Scaffolded files** | Files written once to `src/<Project>/` root — `ServiceCollectionExtensions.cs`, `XxxBusinessDecorator.cs`, `XxxPersistenceDecorator.cs`. The generator will **not** overwrite them on re-run. Hand-edit freely. |
| **Decorator chain** | `LoggingDecorator → BusinessDecorator → PersistenceDecorator → CoreService`. The `BusinessDecorator` and `PersistenceDecorator` are stubs; fill in business rules and persistence calls there. |
| **Outcome\<T\>** | Result envelope from `KoreForge.SwaggerControllers.Abstractions`. Has `Success` (bool), `Data` (T?), `Error` (ErrorInfo?), `CorrelationId` (string). |

---

## Repo Layout

```text
<Repo>/
  Directory.Build.props          # TargetFramework, Nullable, ImplicitUsings, LangVersion, InternalsVisibleTo
  Directory.Packages.props       # Central package versions
  NuGet.config                   # Source mappings — key must be "KoreForgeLocal" for KoreForge.* packages
  <Repo>.slnx                    # Solution, updated by generate.ps1
  scr/
    generate.ps1                 # Copied from KoreForge.SwaggerControllers template; never hand-edit
  swaggers/
    <ApiName>/
      v<N>/
        metadata.json            # Generator input (Stage 1 output)
  src/
    <Repo>.<ApiName>.V<N>/
      <ApiName>.V<N>.csproj
      ServiceCollectionExtensions.cs       # Scaffolded once — edit freely
      <ApiName>BusinessDecorator.cs        # Scaffolded once — add business rules here
      <ApiName>PersistenceDecorator.cs     # Scaffolded once — add persistence calls here
      Generated/
        I<ApiName>ExternalClient.g.cs      # Refit interface
        I<ApiName>Service.g.cs             # Service interface (Outcome<T> returns)
        <ApiName>Service.g.cs              # Core service: Refit calls + exception handling
        <ApiName>LoggingDecorator.g.cs     # Logs every call outcome
        <ApiName>Controller.g.cs           # ASP.NET Core controller ([Authorize(Policy=...)])
        Permissions.g.cs                   # String constants for policy names
        Dtos/
          *.g.cs                           # One file per DTO
  tst/
    <Repo>.Tests/
      <ApiName>V<N>Tests.cs                # Scaffolded once — add tests here
```

---

## Step 1 — Bootstrap a new library repo

1. Copy the `KoreForge.SwaggerControllers` template to a new folder under `event/`.
2. Rename `.slnx`, update `Directory.Build.props` and `Directory.Packages.props`.
3. Verify `NuGet.config` uses `KoreForgeLocal` (capital K, capital F) as the source key for `KoreForge.*` packages.
4. Set `KoreForge.SwaggerControllers.Abstractions` version in `Directory.Packages.props` to the latest packed version in `artifacts/packages`.

---

## Step 2 — Prepare metadata.json files

For each external API:

1. Place a `swaggers/<ApiName>/v<N>/swagger.yml` (or `.yaml` / `.json`) in the repo.
2. Run the `parse-swagger` skill to produce `swaggers/<ApiName>/v<N>/metadata.json`.
3. If the target namespace should differ from the template default, patch `metadata.json`:
   - `projectName` and `namespace` — e.g. `Event.FraudIntegrationControllers.CashoutOrchestrator.V1`
   - Keep `apiName` and `kebabName` unchanged.

### metadata.json shape (reference)

```json
{
  "apiName": "Sample",
  "folderVersion": 1,
  "kebabName": "sample",
  "projectName": "Sample.Test.Sample.V1",
  "namespace": "Sample.Test.Sample.V1",
  "basePath": "/sample/v1",
  "auth": {
    "hasClientId": false,
    "hasClientSecret": false,
    "hasTokenUrl": false,
    "hasScope": false
  },
  "operations": [
    {
      "operationKey": "ListWidgets",
      "operationId": "ListWidgets",
      "httpMethod": "GET",
      "pathTemplate": "/widgets",
      "internalMethodName": "ListWidgetsAsync",
      "refitMethodName": "ListWidgetsAsync",
      "controllerRoute": "widgets",
      "tags": ["Sample"],
      "parameters": [
        {
          "name": "pageSize",
          "csharpName": "PageSize",
          "csharpType": "int?",
          "in": "query",
          "required": false,
          "isBodyParam": false
        }
      ],
      "requestBodyDtoRef": null,
      "successResponseDtoRef": "IReadOnlyList<Widget>",
      "successStatusCode": 200
    }
  ],
  "dtos": [
    {
      "csharpName": "Widget",
      "properties": [
        { "csharpName": "Id", "jsonName": "id", "csharpType": "string", "required": true },
        { "csharpName": "Description", "jsonName": "description", "csharpType": "string", "required": false }
      ]
    }
  ]
}
```

**Property nullability rules**:
- `required: true` + non-nullable type → emits `public required string Name { get; set; }`
- `required: false` + non-nullable type → emits `public string? Name { get; set; }`
- Already-nullable types (ending `?`) are emitted as-is regardless of `required`.

---

## Step 3 — Run the generator

```powershell
pwsh -File "scr/generate.ps1" -RepoRoot "<absolute-path-to-repo>"
```

The generator:
- Reads every `swaggers/**/metadata.json`.
- Writes all `Generated/` files (overwriting).
- Scaffolds `ServiceCollectionExtensions.cs`, `XxxBusinessDecorator.cs`, `XxxPersistenceDecorator.cs`, `XxxV<N>Tests.cs`, and `.csproj` **only if they do not exist**.
- Updates the `.slnx` solution file to include all projects.

Re-running is safe — only `Generated/` files are ever overwritten.

---

## Step 4 — Fix the project after first generation

1. Verify `Directory.Build.props` has:
   ```xml
   <TargetFramework>net10.0</TargetFramework>
   <Nullable>enable</Nullable>
   <ImplicitUsings>enable</ImplicitUsings>
   <LangVersion>latest</LangVersion>
   <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
   ```
2. Add `InternalsVisibleTo` to `Directory.Build.props` so tests can access internal service classes:
   ```xml
   <ItemGroup Condition="'$(IsTestProject)' != 'true'">
     <AssemblyAttribute Include="System.Runtime.CompilerServices.InternalsVisibleToAttribute">
       <_Parameter1><Repo>.Tests</_Parameter1>
     </AssemblyAttribute>
   </ItemGroup>
   ```
3. Verify `NuGet.config` source key for `KoreForge.*` is `KoreForgeLocal`.

---

## Step 5 — Customise the decorator chain

The scaffolded decorators are pass-through stubs. Fill them in:

- **BusinessDecorator** — validation, enrichment, caching, business rules before or after the core call.
- **PersistenceDecorator** — audit logging, database writes, idempotency checks.

Do **not** modify any file inside `Generated/`. Those are overwritten by the generator.

---

## Step 6 — Wire DI in the host app

Call the generated extension in `Program.cs` or `Startup.cs`:

```csharp
builder.Services.AddSampleV1Services(opts =>
{
    opts.Mode = AuthMode.ClientCredentials;
    opts.ClientId = config["Sample:ClientId"]!;
    opts.ClientSecret = config["Sample:ClientSecret"]!;
});
builder.Services.AddSampleV1Controllers();  // optional — registers controller assembly part
```

The `ServiceCollectionExtensions.cs` wires the full chain: `LoggingDecorator → BusinessDecorator → PersistenceDecorator → CoreService → RefitClient`.

---

## Step 7 — Write tests

Test files are scaffolded once at `tst/<Repo>.Tests/<ApiName>V<N>Tests.cs`. The initial scaffold contains:

- `DiRegistration_ResolvesService` — builds a `ServiceCollection`, calls `AddXxxV<N>Services`, resolves `IXxxService`.
- `Outcome_Ok_ReturnsSuccess` / `Outcome_Fail_ReturnsError` — smoke tests for the `Outcome<T>` type.

### Adding service unit tests (recommended pattern)

Since core service classes are `internal`, tests access them via `InternalsVisibleTo` (see Step 4).

```csharp
using Refit;

[Fact]
public async Task SomeMethodAsync_Success_ReturnsOk()
{
    var mockClient = Substitute.For<ISampleExternalClient>();
    var expected = new SomeResponseDto();
    mockClient.SomeMethodAsync(Arg.Any<CancellationToken>())
        .Returns(Task.FromResult(expected));

    var svc = new SampleService(mockClient, NullLogger<SampleService>.Instance);
    var outcome = await svc.SomeMethodAsync();

    Assert.True(outcome.Success);
    Assert.Same(expected, outcome.Data);
}

[Fact]
public async Task SomeMethodAsync_ApiException_ReturnsExternalFail()
{
    var mockClient = Substitute.For<ISampleExternalClient>();
    var apiEx = await ApiException.Create(
        new HttpRequestMessage(HttpMethod.Get, "https://api.example.com"),
        HttpMethod.Get,
        new HttpResponseMessage(System.Net.HttpStatusCode.BadGateway),
        new RefitSettings());
    mockClient.SomeMethodAsync(Arg.Any<CancellationToken>())
        .Returns(Task.FromException<SomeResponseDto>(apiEx));

    var svc = new SampleService(mockClient, NullLogger<SampleService>.Instance);
    var outcome = await svc.SomeMethodAsync();

    Assert.False(outcome.Success);
    Assert.Equal(ErrorOrigin.External, outcome.Error!.Origin);
}

[Fact]
public async Task SomeMethodAsync_Exception_ReturnsInternalFail()
{
    var mockClient = Substitute.For<ISampleExternalClient>();
    mockClient.SomeMethodAsync(Arg.Any<CancellationToken>())
        .Returns(Task.FromException<SomeResponseDto>(new InvalidOperationException("fail")));

    var svc = new SampleService(mockClient, NullLogger<SampleService>.Instance);
    var outcome = await svc.SomeMethodAsync();

    Assert.False(outcome.Success);
    Assert.Equal(ErrorOrigin.Internal, outcome.Error!.Origin);
}
```

Test project `Directory.Packages.props` must reference:
- `NSubstitute` (for mocking)
- `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`, `coverlet.collector`
- `FrameworkReference Include="Microsoft.AspNetCore.App"` (for ASP.NET + Refit)

---

## Common Errors

| Error | Cause | Fix |
| --- | --- | --- |
| `CS8618` on DTO property | DTO has non-nullable non-required property. Missing `required` modifier or `?` suffix. | Re-run generator after setting `required: true` or `required: false` in `metadata.json`. |
| Package source mapping failure | `NuGet.config` source key for `KoreForge.*` is not `KoreForgeLocal`. | Rename key to `KoreForgeLocal` (capital K, F). |
| `AddProvider` not found in test | Missing `using Microsoft.Extensions.Logging;`. | Add the using; it's separate from `.Abstractions`. |
| Generator fails with `The property 'required' cannot be found` | PowerShell strict mode + missing metadata property. | Ensure generator uses `$null -ne ($prop.PSObject.Properties['required'])` guard. |
| Scaffold not overwritten as expected | Generator only writes scaffolded files if they do not exist. | Delete the file and re-run the generator to refresh the scaffold. |

---

## Package Versions (as of this writing)

| Package | Version |
| --- | --- |
| `KoreForge.SwaggerControllers.Abstractions` | `0.0.0-alpha.0.6` |
| `Refit` / `Refit.HttpClientFactory` | `8.0.0` |
| `NSubstitute` | `5.3.0` |
