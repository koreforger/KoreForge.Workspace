# KoreForge.Processing — API Reference

**Package**: `KoreForge.Processing`  |  **Namespaces**: see below

Multi-assembly package:

| Assembly | Namespace | Contents |
|----------|-----------|----------|
| `KF.Processing.Pipeline.dll` | `KoreForge.Processing.Pipeline` | `Pipeline` builder, `IPipeline<TIn,TOut>` |
| `KF.Processing.Pipeline.Abstractions.dll` | `KoreForge.Processing.Pipeline.Abstractions` | `IPipelineStep<TIn,TOut>`, `IPipelineContext` |
| `KF.Processing.Flow.dll` | `KoreForge.Processing.Flow` | `Flow` builder, `IFlow<TContext>` |
| `KF.Processing.Flow.Abstractions.dll` | `KoreForge.Processing.Flow.Abstractions` | `IFlowStage<TContext>`, `IFlowContext` |
| `KF.Processing.Pipelines.dll` | `KoreForge.Processing.Pipelines` | Built-in pipeline composite types |

---

## Pipeline Abstractions

### `IPipelineStep<TIn, TOut>` Interface

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipelineStep<TIn, TOut>
{
    /// Execute this step: transform input to output.
    Task<TOut> ExecuteAsync(TIn input, IPipelineContext context, CancellationToken cancellationToken);
}
```

### `IPipelineContext` Interface

Flows through all steps in a pipeline execution; provides DI and cross-step state.

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipelineContext
{
    /// Resolve a service from DI mid-pipeline.
    T GetService<T>() where T : notnull;

    /// Per-execution property bag for cross-step data.
    IDictionary<string, object?> Properties { get; }

    /// Propagated cancellation token for the pipeline execution.
    CancellationToken CancellationToken { get; }
}
```

### `IPipeline<TIn, TOut>` Interface

Represents a built, executable pipeline.

```csharp
namespace KoreForge.Processing.Pipeline.Abstractions;

public interface IPipeline<TIn, TOut>
{
    /// Execute all steps in order, starting with input, returning the final output.
    Task<TOut> ExecuteAsync(TIn input, CancellationToken cancellationToken);

    /// Execute with explicit initial context (for property pre-seeding).
    Task<TOut> ExecuteAsync(TIn input, IPipelineContext context, CancellationToken cancellationToken);
}
```

---

## Pipeline Builder

### `Pipeline` Static Class

Entry point for building pipelines.

```csharp
namespace KoreForge.Processing.Pipeline;

public static class Pipeline
{
    /// Start building a pipeline with the given input type.
    /// Steps are resolved from DI when the pipeline is built with a service provider.
    public static IPipelineBuilder<T, T> Start<T>(IServiceProvider? serviceProvider = null);
}
```

### `IPipelineBuilder<TIn, TOut>` Interface

Fluent builder returned by `Pipeline.Start<T>()`.

```csharp
namespace KoreForge.Processing.Pipeline;

public interface IPipelineBuilder<TIn, TOut>
{
    /// Add a step whose output type becomes the new TOut.
    IPipelineBuilder<TIn, TNext> AddStep<TStep, TNext>()
        where TStep : IPipelineStep<TOut, TNext>;

    /// Shorthand when step type parameters can be inferred.
    IPipelineBuilder<TIn, TNext> AddStep<TStep>()
        where TStep : IPipelineStep<TOut, TNext>;

    /// Build the pipeline into an executable IPipeline<TIn, TOut>.
    IPipeline<TIn, TOut> Build();
}
```

---

## Flow Abstractions

### `IFlowStage<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlowStage<TContext>
{
    /// Execute this stage; mutate context in place.
    Task ExecuteAsync(TContext context, IFlowContext flowContext, CancellationToken cancellationToken);
}
```

### `IFlowContext` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlowContext
{
    /// Name assigned to this flow instance.
    string FlowName { get; }

    /// Zero-based index of the currently executing stage.
    int CurrentStageIndex { get; }

    /// Name of the currently executing stage (type name by default).
    string CurrentStageName { get; }

    /// Resolve additional services from DI.
    T GetService<T>() where T : notnull;

    /// Per-execution property bag.
    IDictionary<string, object?> Properties { get; }
}
```

### `IFlow<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow.Abstractions;

public interface IFlow<TContext>
{
    /// Execute all stages in order, passing context to each.
    Task ExecuteAsync(TContext context, CancellationToken cancellationToken);
}
```

---

## Flow Builder

### `Flow` Static Class

```csharp
namespace KoreForge.Processing.Flow;

public static class Flow
{
    /// Start building a named flow with the given context type.
    public static IFlowBuilder<TContext> Create<TContext>(
        string flowName,
        IServiceProvider? serviceProvider = null);
}
```

### `IFlowBuilder<TContext>` Interface

```csharp
namespace KoreForge.Processing.Flow;

public interface IFlowBuilder<TContext>
{
    /// Add a stage; resolved from DI.
    IFlowBuilder<TContext> AddStage<TStage>()
        where TStage : IFlowStage<TContext>;

    /// Add a stage instance directly (no DI resolution).
    IFlowBuilder<TContext> AddStage(IFlowStage<TContext> stage);

    /// Build into an executable IFlow<TContext>.
    IFlow<TContext> Build();
}
```

---

## Built-in Pipeline Types (`KoreForge.Processing.Pipelines`)

### `BatchPipeline<TIn, TOut>`

Processes a collection of items through a shared pipeline in parallel or sequential mode.

```csharp
namespace KoreForge.Processing.Pipelines;

public sealed class BatchPipeline<TIn, TOut>
{
    public BatchPipeline(IPipeline<TIn, TOut> inner, BatchPipelineOptions options);

    /// Process all items in the batch. Returns results in input order.
    Task<IReadOnlyList<TOut>> ExecuteAsync(
        IReadOnlyList<TIn> items,
        CancellationToken cancellationToken);
}

public sealed class BatchPipelineOptions
{
    /// Maximum degree of parallelism. Default: 1 (sequential).
    public int MaxDegreeOfParallelism { get; set; }

    /// Whether to continue processing remaining items when one fails. Default: false.
    public bool ContinueOnError { get; set; }
}
```

---

## Exceptions

### `PipelineException`

Thrown when a pipeline step fails.

```csharp
namespace KoreForge.Processing.Pipeline;

public sealed class PipelineException : Exception
{
    /// Name of the step that threw.
    public string StepName { get; }

    /// Zero-based index of the failing step.
    public int StepIndex { get; }
}
```

### `FlowException`

Thrown when a flow stage fails.

```csharp
namespace KoreForge.Processing.Flow;

public sealed class FlowException : Exception
{
    public string FlowName    { get; }
    public string StageName   { get; }
    public int    StageIndex  { get; }
}
```
