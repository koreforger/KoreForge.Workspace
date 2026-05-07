---
name: koreforge-processing
description: "Use when building data transformation pipelines, batch processing, or step-based processing in a KoreForge application. Covers KoreForge.Processing: PipelineBuilder, BatchPipelineExecutor, IPipelineStep, IPipelineMetrics, pipeline configuration."
---

# KoreForge Processing Skill

## Package

```xml
<PackageReference Include="KoreForge.Processing" />
```

## Pipeline Building

```csharp
// Build a typed pipeline for a single item
var pipeline = PipelineBuilder
    .Create<ProcessingContext>()
    .UseStep<ValidateStep>()
    .UseStep<EnrichStep>()
    .UseStep<PersistStep>()
    .Build();

// Execute for one item
var result = await pipeline.RunAsync(new ProcessingContext { ... }, cancellationToken);
```

`Build()` returns an `IPipeline<T>` — register it as a singleton if steps are stateless.

## Implementing Steps

```csharp
public sealed class ValidateStep : IPipelineStep<ProcessingContext>
{
    public async Task<StepOutcome> ExecuteAsync(ProcessingContext context, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(context.Payload))
            return StepOutcome.Failure("Payload is required");

        return StepOutcome.Continue;  // proceed to next step
    }
}

public sealed class EnrichStep : IPipelineStep<ProcessingContext>
{
    private readonly ILookupService _lookup;

    public EnrichStep(ILookupService lookup) => _lookup = lookup;

    public async Task<StepOutcome> ExecuteAsync(ProcessingContext context, CancellationToken ct)
    {
        context.Metadata = await _lookup.GetAsync(context.EntityId, ct);
        return StepOutcome.Continue;
    }
}
```

### StepOutcome Values

| Value | Effect |
|-------|--------|
| `StepOutcome.Continue` | Move to next step |
| `StepOutcome.Success` | Halt pipeline, result is success |
| `StepOutcome.Failure("reason")` | Halt pipeline, result is failure |
| `StepOutcome.Skip` | Skip this step (from conditional branch) |

## Batch Processing

`BatchPipelineExecutor<TIn, TOut>` runs a pipeline against a list of items in parallel, collecting results:

```csharp
var executor = new BatchPipelineExecutor<ProcessingContext, ProcessedRecord>(
    pipeline,
    context => context.Result,         // selector — how to extract the output from context
    maxDegreeOfParallelism: 4);

var batch = items.Select(i => new ProcessingContext { Payload = i }).ToList();
var results = await executor.ExecuteAsync(batch, cancellationToken);

var succeeded = results.Where(r => r.IsSuccess).ToList();
var failed    = results.Where(r => !r.IsSuccess).ToList();
```

## Registering Steps in DI

Steps are resolved per pipeline run via DI. Register them according to their state:

```csharp
// Stateless steps — safe to share
builder.Services.AddSingleton<ValidateStep>();

// Stateful or DbContext-dependent steps — scoped
builder.Services.AddScoped<PersistStep>();
builder.Services.AddTransient<EnrichStep>();
```

When the pipeline is used inside a scoped context (e.g. HTTP request), steps resolve from that scope.

## Pipeline Context

Define a context class that carries data between steps:

```csharp
public sealed class ProcessingContext
{
    // Input — set before pipeline runs
    public string Payload { get; init; } = "";
    public Guid EntityId { get; init; }

    // Intermediate state — steps populate during execution
    public EntityMetadata? Metadata { get; set; }

    // Output — final step sets this
    public ProcessedRecord? Result { get; set; }
}
```

## Metrics Integration

Implement `IPipelineMetrics` to hook into the pipeline lifecycle for `IOperationMonitor`:

```csharp
public sealed class MonitoredPipelineMetrics : IPipelineMetrics
{
    private readonly IOperationMonitor _monitor;

    public MonitoredPipelineMetrics(IOperationMonitor monitor) => _monitor = monitor;

    public IDisposable BeginStep(string pipelineName, string stepName)
        => _monitor.Begin($"{pipelineName}.{stepName}");
}

// Register
builder.Services.AddSingleton<IPipelineMetrics, MonitoredPipelineMetrics>();
```

When `IPipelineMetrics` is registered in DI, `PipelineBuilder` picks it up automatically.

## Pipeline Configuration via Options

```csharp
var pipeline = PipelineBuilder
    .Create<ProcessingContext>()
    .Configure(options =>
    {
        options.ContinueOnStepFailure = false;   // default — abort on first failure
        options.ThrowOnFailure = false;           // default — return failure result, no exception
    })
    .UseStep<ValidateStep>()
    .UseStep<EnrichStep>()
    .Build();
```

## Checklist

- [ ] `KoreForge.Processing` in `Directory.Packages.props` + `.csproj`
- [ ] Each step implements `IPipelineStep<TContext>` with a single `ExecuteAsync` method
- [ ] `StepOutcome.Continue` used for intermediate steps, `StepOutcome.Success` for terminal steps
- [ ] Steps registered in DI matching their state characteristics (singleton/scoped/transient)
- [ ] `IPipelineMetrics` wired if `IOperationMonitor` is available
- [ ] Pipeline built once and reused — do not rebuild per-request
