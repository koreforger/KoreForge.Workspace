# KoreForge.Kafka

| | |
|---|---|
| **Package** | `KoreForge.Kafka` (meta), `KoreForge.Kafka.Consumer`, `KoreForge.Kafka.Producer`, `KoreForge.Kafka.AdminClient`, `KoreForge.Kafka.Configuration`, `KoreForge.Kafka.Configuration.AspNetCore`, `KoreForge.Kafka.Core` |
| **Namespace** | `KoreForge.Kafka.*` |
| **Source** | `KoreForge.Kafka/src/` |
| **Tests** | `KoreForge.Kafka/tst/` |
| **Dependencies** | Confluent.Kafka, KoreForge.Metrics, KoreForge.Logging |

## Problem

Kafka client code in .NET is low-level: you must manage consumer loops, deserialization, offset commits, error handling, backpressure, retries, and graceful shutdown yourself. Each team reinvents the same resilient wrapper, and the resulting code is tightly coupled to Confluent.Kafka primitives.

Producers face similar problems: buffering, delivery reports, backlog management, and backpressure are all left as exercises for the reader.

Monitoring consumer lag and topic health requires additional tooling that doesn't ship with the client library.

## Solution

KoreForge.Kafka provides a production-grade Kafka stack built on Confluent.Kafka:

- **Consumer:** Hosted service with automatic restart, pipeline integration, batch processing, backpressure, and structured logging.
- **Producer:** Buffered producer with delivery tracking, backpressure, backlog management, and metrics emission.
- **Admin Client:** Read-only surface for topic metadata, consumer-lag queries, and offsets-for-timestamp.
- **Configuration:** Profile-based configuration model with validation and generated factories.

## Compromises

- Requires Confluent.Kafka — not an abstraction over arbitrary message brokers.
- Consumer uses a single-threaded partition model per consumer group. High-throughput scenarios should deploy multiple consumer instances.
- The meta-package `KoreForge.Kafka` pulls in all sub-packages. Use individual packages for leaner dependency trees.

## Installation

```bash
# Everything
dotnet add package KoreForge.Kafka

# Or pick what you need
dotnet add package KoreForge.Kafka.Consumer
dotnet add package KoreForge.Kafka.Producer
dotnet add package KoreForge.Kafka.AdminClient
```

## Configuration

Define profiles in `appsettings.json`:

```json
{
  "Kafka": {
    "Profiles": {
      "Default": {
        "BootstrapServers": "localhost:29092",
        "SecurityProtocol": "Plaintext"
      }
    }
  }
}
```

## DI Registration

```csharp
// 1. Register configuration profiles
services.AddKafkaConfiguration(configuration.GetSection("Kafka"));

// 2. Register a producer
services.AddKafkaProducer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topic = "my-events";
});

// 3. Register a consumer
services.AddKafkaConsumer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topics = new[] { "my-events" };
    options.GroupId = "my-service";
});

// 4. Register admin client (optional)
services.AddKafkaAdminClient(configuration.GetSection("Kafka:Admin"));
```

## API Reference

### Producer

Inject `IKafkaProducer<TKey, TValue>`:

```csharp
public class OrderPublisher(IKafkaProducer<string, OrderCreated> producer)
{
    public Task PublishAsync(OrderCreated evt, CancellationToken ct)
        => producer.EnqueueAsync(evt.OrderId, evt, ct);
}
```

### Consumer

Implement `IKafkaMessageHandler<TKey, TValue>`:

```csharp
public class OrderHandler : IKafkaMessageHandler<string, OrderCreated>
{
    public Task HandleAsync(ConsumeResult<string, OrderCreated> message, CancellationToken ct)
    {
        // Process the message
        return Task.CompletedTask;
    }
}
```

### Admin Client

Inject `IKafkaAdminClient`:

```csharp
public class LagMonitor(IKafkaAdminClient admin)
{
    public async Task<ConsumerGroupLagSummary> GetLagAsync()
        => await admin.GetConsumerGroupLagSummaryAsync(
            "my-service",
            new ConsumerGroupLagQuery { TopicFilter = new[] { "my-events" } });
}
```

## Sub-Packages

| Package | Description |
|---|---|
| `KoreForge.Kafka` | Meta-package — installs all components below |
| `KoreForge.Kafka.AdminClient` | Read-only admin: topic metadata, consumer-lag, offsets-for-timestamp |
| `KoreForge.Kafka.Configuration` | Configuration model, profiles, validation, generated factories |
| `KoreForge.Kafka.Configuration.AspNetCore` | ASP.NET Core integration for configuration |
| `KoreForge.Kafka.Consumer` | Resilient consumer host with backpressure, routing, pipeline, restart |
| `KoreForge.Kafka.Core` | Shared runtime records, alert engine, diagnostics |
| `KoreForge.Kafka.Producer` | Resilient producer with buffering, backpressure, backlog, metrics |

## Docker Dev Environment

A local development environment ships in `samples/docker/`:

| Component | Port | Purpose |
|---|---|---|
| Redpanda | `29092` | Kafka-compatible broker |
| Azure SQL Edge | `14333` | SQL Server for settings/state |

```powershell
.\samples\docker\up.ps1     # Start and configure infrastructure
.\samples\docker\down.ps1   # Stop
```

## See Also

- `KoreForge.Kafka/doc/UsageGuide.md` — Extended usage examples
- `KoreForge.Kafka/doc/AdminClient.md` — Admin client reference
- `KoreForge.Kafka/samples/docker/` — Docker Compose files
