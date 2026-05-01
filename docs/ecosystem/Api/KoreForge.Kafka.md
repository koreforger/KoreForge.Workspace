# KoreForge.Kafka — API Reference

**Package**: `KoreForge.Kafka`  |  **Namespace root**: `KoreForge.Kafka`

Multi-assembly package:

| Assembly | Namespace | Contents |
|----------|-----------|----------|
| `KF.Kafka.Consumer.dll` | `KoreForge.Kafka.Consumer` | `KafkaConsumerHost`, `IKafkaBatchProcessor` |
| `KF.Kafka.Producer.dll` | `KoreForge.Kafka.Producer` | `KafkaProducerHost`, `IProducerBuffer` |
| `KF.Kafka.AdminClient.dll` | `KoreForge.Kafka.AdminClient` | `KafkaAdminClient` |
| `KF.Kafka.Pipeline.dll` | `KoreForge.Kafka.Pipeline` | `KafkaPipelineProcessorBuilder` |
| `KF.Kafka.Configuration.dll` | `KoreForge.Kafka.Configuration` | Options, policy types |
| `KF.Kafka.Abstractions.dll` | `KoreForge.Kafka.Abstractions` | Shared interfaces |

---

## Consumer

### `IKafkaBatchProcessor` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IKafkaBatchProcessor
{
    /// Process a batch of Kafka messages.
    Task ProcessBatchAsync(
        IReadOnlyList<ConsumeResult<Ignore, string>> batch,
        CancellationToken cancellationToken);
}
```

### `KafkaConsumerHost` Class

`IHostedService` that polls Kafka and dispatches batches to `IKafkaBatchProcessor`. Registered automatically by `AddKafkaConsumer`.

```csharp
namespace KoreForge.Kafka.Consumer;

public sealed class KafkaConsumerHost : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken);
}
```

### `ConsumerOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ConsumerOptions
{
    public string        BootstrapServers  { get; set; }  // required
    public string        GroupId           { get; set; }  // required
    public List<string>  Topics            { get; set; }  // required
    public int           MaxBatchSize      { get; set; }  // default: 100
    public int           FlushIntervalMs   { get; set; }  // default: 50
    public AutoOffsetReset AutoOffsetReset { get; set; }  // default: Earliest
    public bool          EnableAutoCommit  { get; set; }  // default: false
    public int           SessionTimeoutMs  { get; set; }  // default: 30000

    /// Backpressure policy; default: no backpressure.
    public IBackpressurePolicy? Backpressure { get; set; }

    /// Restart policy on consumer loop failure; default: DefaultConsumerRestartPolicy.
    public IRestartPolicy? RestartPolicy { get; set; }
}
```

### Registration

```csharp
builder.Services.AddKafkaConsumer(Action<ConsumerOptions> configure);
builder.Services.AddScoped<IKafkaBatchProcessor, MyBatchProcessor>();
```

---

## Producer

### `IProducerBuffer` Interface

Enqueue messages for async batched publishing to Kafka.

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IProducerBuffer
{
    /// Enqueue a message to the default topic.
    ValueTask EnqueueAsync<T>(T message, CancellationToken cancellationToken);

    /// Enqueue a message to an explicit topic.
    ValueTask EnqueueAsync<T>(T message, string topic, CancellationToken cancellationToken);

    /// Enqueue with an explicit partition key.
    ValueTask EnqueueAsync<T>(T message, string topic, string partitionKey, CancellationToken cancellationToken);

    /// Current number of messages waiting to be flushed.
    int PendingCount { get; }
}
```

### `KafkaProducerHost` Class

`IHostedService` that batches messages from `IProducerBuffer` and flushes to Kafka. Registered automatically by `AddKafkaProducer`.

### `ProducerOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ProducerOptions
{
    public string BootstrapServers { get; set; }   // required
    public string DefaultTopic     { get; set; }   // required
    public int    MaxBatchSize     { get; set; }   // default: 200
    public int    LingerMs         { get; set; }   // default: 5
    public string? CompressionType { get; set; }  // "none" | "gzip" | "snappy" | "lz4"

    public IRestartPolicy? RestartPolicy { get; set; }
}
```

### Registration

```csharp
builder.Services.AddKafkaProducer(Action<ProducerOptions> configure);
// IProducerBuffer is registered automatically
```

---

## Pipeline Integration

### `KafkaPipelineProcessorBuilder`

Wires a `KoreForge.Processing` pipeline to the Kafka consumer batch.

```csharp
// Registration
builder.Services.AddKafkaPipelineProcessor(pb =>
{
    pb.UseMessagesPerBatch(500)
      .UseDeserializer<JsonMessageDeserializer<OrderMessage>>()
      .UsePipeline<OrderMessage>(pipeline => pipeline
          .AddStep<ValidateOrderStep>()
          .AddStep<EnrichOrderStep>()
          .AddStep<PersistOrderStep>());
});
```

The builder registers an `IKafkaBatchProcessor` implementation internally.

---

## Backpressure Policies

### `IBackpressurePolicy` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IBackpressurePolicy
{
    /// Returns true when Kafka polling should pause.
    bool ShouldPause(int queueDepth);

    /// Returns true when Kafka polling can resume after a pause.
    bool ShouldResume(int queueDepth);
}
```

### `ThresholdBackpressurePolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class ThresholdBackpressurePolicy : IBackpressurePolicy
{
    /// Pause when queue depth exceeds this value. Default: 1000.
    public int PauseThreshold  { get; set; }

    /// Resume when queue depth drops below this value. Default: 200.
    public int ResumeThreshold { get; set; }
}
```

---

## Restart Policies

### `IRestartPolicy` Interface

```csharp
namespace KoreForge.Kafka.Abstractions;

public interface IRestartPolicy
{
    /// True if the host should attempt another restart.
    bool ShouldRestart(int attemptNumber, Exception exception);

    /// Delay before the next restart attempt.
    Task WaitAsync(int attemptNumber, CancellationToken cancellationToken);
}
```

### `FixedRetryRestartPolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class FixedRetryRestartPolicy : IRestartPolicy
{
    public int    MaxRetries    { get; set; }  // default: 5
    public int    DelayMs       { get; set; }  // default: 2000
    public double BackoffFactor { get; set; }  // default: 1.0 (linear); >1 = exponential
}
```

### `DefaultProducerRestartPolicy` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class DefaultProducerRestartPolicy : IRestartPolicy
{
    public int MaxRetries { get; set; }  // default: 10
    public int DelayMs    { get; set; }  // default: 1000
}
```

---

## Admin Client

### `KafkaAdminClient` Class

```csharp
namespace KoreForge.Kafka.AdminClient;

public sealed class KafkaAdminClient : IAsyncDisposable
{
    /// Create a topic if it does not already exist.
    Task CreateTopicIfNotExistsAsync(
        string name,
        int    partitions,
        short  replicationFactor,
        CancellationToken cancellationToken = default);

    /// Delete a topic. Throws if the topic does not exist.
    Task DeleteTopicAsync(string name, CancellationToken cancellationToken = default);

    /// List all topics.
    Task<IReadOnlyList<string>> ListTopicsAsync(CancellationToken cancellationToken = default);

    public ValueTask DisposeAsync();
}
```

### `AdminClientOptions` Class

```csharp
namespace KoreForge.Kafka.Configuration;

public sealed class AdminClientOptions
{
    public string BootstrapServers { get; set; }  // required
}
```

### Registration

```csharp
builder.Services.AddKafkaAdminClient(Action<AdminClientOptions> configure);
```
