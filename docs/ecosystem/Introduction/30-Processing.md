# KoreForge.Processing

| | |
|---|---|
| **Package** | `KoreForge.Processing` |
| **Namespace** | `KoreForge.Processing` |
| **Source** | `KoreForge.Processing/src/` |
| **Tests** | `KoreForge.Processing/tst/` |
| **Dependencies** | Microsoft.Extensions.DependencyInjection.Abstractions |

## Problem

Non-trivial applications need to chain operations together: validate → enrich → transform → persist. Without a formal structure, these chains end up as nested method calls, deeply indented `if` blocks, or ad-hoc "service" classes with names like `OrderProcessingOrchestrator`. The control flow is hidden inside imperative code, making it hard to test individual steps, reorder them, or add cross-cutting concerns like timing and error handling.

## Solution

KoreForge.Processing provides two composable patterns:

**Pipelines** for linear data transformation — each step takes an input type and produces a new output type. Steps are pure functions that can be tested in isolation.

**Flows** for state-machine orchestration — stages share a mutable context and can branch to different next stages based on outcomes.

Both patterns support DI-resolved steps/stages, cancellation, and pluggable observability.

## Compromises

- The pipeline generic signature `IPipelineStep<TIn, TOut>` can become verbose with many steps. This is intentional — the types document the data flow at the interface level.
- Flows use mutable context objects, which sacrifices the immutability of pipelines. This is the right trade-off for processes where stages need to share state.

## Installation

```bash
dotnet add package KoreForge.Processing
```

## DI Registration

Steps and stages are resolved from the DI container automatically when registered:

```csharp
builder.Services.AddTransient<ValidateOrderStep>();
builder.Services.AddTransient<EnrichOrderStep>();
builder.Services.AddTransient<PersistOrderStep>();
```

## Configuration

No configuration options. Pipeline and flow behavior is defined by the builder API.

## API Reference

### Building a Pipeline

```csharp
var pipeline = Pipeline
    .Start<RawOrder>()
    .AddStep<ValidateOrderStep>()     // RawOrder → ValidatedOrder
    .AddStep<EnrichOrderStep>()       // ValidatedOrder → EnrichedOrder
    .AddStep<PersistOrderStep>()      // EnrichedOrder → PersistedOrder
    .Build();

var result = await pipeline.ExecuteAsync(rawOrder, context, cancellationToken);
```

### Writing a Pipeline Step

```csharp
public class ValidateOrderStep : IPipelineStep<RawOrder, ValidatedOrder>
{
    public Task<ValidatedOrder> ExecuteAsync(
        RawOrder input,
        IPipelineContext context,
        CancellationToken cancellationToken)
    {
        // Validate and transform
        return Task.FromResult(new ValidatedOrder(input));
    }
}
```

### `IPipelineContext`

```csharp
public interface IPipelineContext
{
    T GetService<T>();                         // Resolve from DI
    IDictionary<string, object> Properties;    // Shared properties bag
    CancellationToken CancellationToken { get; }
}
```

### Building a Flow

```csharp
var flow = Flow
    .Create<CheckoutContext>("checkout")
    .AddStage<ValidateCartStage>()
    .AddStage<ProcessPaymentStage>()
    .AddStage<ConfirmOrderStage>()
    .Build();

var context = new CheckoutContext { Cart = cart };
await flow.ExecuteAsync(context, flowCtx, cancellationToken);
```

### Writing a Flow Stage

```csharp
public class ValidateCartStage : IFlowStage<CheckoutContext>
{
    public Task ExecuteAsync(
        CheckoutContext context,
        IFlowContext flowCtx,
        CancellationToken cancellationToken)
    {
        // Validate and mutate context
        context.IsValid = context.Cart.Items.Count > 0;
        return Task.CompletedTask;
    }
}
```

### Package Assemblies

| Assembly | Contains |
|----------|---------|
| `KF.Processing.Pipeline.dll` | Pipeline builder and execution |
| `KF.Processing.Pipeline.Abstractions.dll` | `IPipelineStep`, `IPipelineContext` |
| `KF.Processing.Flow.dll` | Flow builder and execution |
| `KF.Processing.Flow.Abstractions.dll` | `IFlowStage`, `IFlowContext` |
| `KF.Processing.Pipelines.dll` | Built-in compound types |

## Pipeline vs Flow — Decision Guide

| Question | Pipeline | Flow |
|----------|----------|------|
| Does each step produce a new type? | Yes | No |
| Is the work data transformation? | Yes | No |
| Do stages share mutable state? | No | Yes |
| Can stages branch based on outcomes? | No | Yes |
| Is it a business process with many actors? | No | Yes |
