# KoreForge.Logging.Serilog

| | |
|---|---|
| **Package** | `KoreForge.Logging.Serilog` |
| **Namespace** | `KoreForge.Logging.Serilog` |
| **Source** | `KoreForge.Logging.Serilog/src/KoreForge.Logging.Serilog/` |
| **Dependencies** | KoreForge.Logging, Serilog |

## Problem

Many production environments use Serilog with LogStash-format sinks for centralized log aggregation. The standard `Microsoft.Extensions.Logging` → Serilog bridge works, but KoreForge's generated log events need specific sink configuration to preserve the hierarchical event structure in LogStash-format output.

## Solution

KoreForge.Logging.Serilog provides preconfigured Serilog sink integration that preserves KoreForge log event metadata (event IDs, hierarchy) in the output format.

## Compromises

- Adds a direct dependency on Serilog. If you use a different logging backend, you do not need this package.

## Installation

```bash
dotnet add package KoreForge.Logging.Serilog
```

## DI Registration

```csharp
builder.Host.UseSerilog((context, config) =>
{
    config
        .ReadFrom.Configuration(context.Configuration)
        .AddKoreForgeLogStash(options =>
        {
            options.IncludeEventHierarchy = true;
        });
});
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `IncludeEventHierarchy` | bool | `true` | Include the full event hierarchy path in log output |
