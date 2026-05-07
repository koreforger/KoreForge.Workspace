---
name: koreforge-kafka
description: "Use when adding, fixing, or reviewing Kafka producer, consumer, or admin client integration in a KoreForge application. Covers KoreForge.Kafka: AddKafkaConfiguration, AddKafkaProducer, AddKafkaConsumer, AddKafkaAdminClient, IKafkaProducer, IKafkaMessageHandler, IKafkaAdminClient."
---

# KoreForge Kafka Skill

## Package

```xml
<PackageReference Include="KoreForge.Kafka" />
```

## Step 1 — Configuration

Define a Kafka profile in `appsettings.json`:

```json
{
  "Kafka": {
    "Profiles": {
      "Default": {
        "BootstrapServers": "localhost:29092",
        "SecurityProtocol": "Plaintext"
      },
      "Secure": {
        "BootstrapServers": "kafka.prod.example.com:9093",
        "SecurityProtocol": "SaslSsl",
        "SaslMechanism": "ScramSha256",
        "SaslUsername": "my-user",
        "SaslPassword": "my-password"
      }
    }
  }
}
```

Register in DI:

```csharp
services.AddKafkaConfiguration(configuration.GetSection("Kafka"));
```

## Step 2 — Producer

```csharp
// Register
services.AddKafkaProducer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topic = "my-events";
});

// Use
public sealed class EventPublisher
{
    private readonly IKafkaProducer<string, MyEvent> _producer;

    public EventPublisher(IKafkaProducer<string, MyEvent> producer) => _producer = producer;

    public async Task PublishAsync(MyEvent evt, CancellationToken ct)
    {
        await _producer.EnqueueAsync(evt.Id.ToString(), evt);
    }
}
```

## Step 3 — Consumer

```csharp
// Register
services.AddKafkaConsumer<string, MyEvent>(options =>
{
    options.ProfileName = "Default";
    options.Topics = new[] { "my-events" };
    options.GroupId = "my-service";
});

// Implement the handler
public sealed class MyEventHandler : IKafkaMessageHandler<string, MyEvent>
{
    public Task HandleAsync(string key, MyEvent value, CancellationToken ct)
    {
        // Process the message
        return Task.CompletedTask;
    }
}
```

## Step 4 — Admin Client

```csharp
// Register
services.AddKafkaAdminClient(configuration.GetSection("Kafka:Admin"));

// Use
public sealed class KafkaMonitorService
{
    private readonly IKafkaAdminClient _admin;

    public KafkaMonitorService(IKafkaAdminClient admin) => _admin = admin;

    public async Task<long> GetLagAsync(CancellationToken ct)
    {
        var lag = await _admin.GetConsumerGroupLagSummaryAsync(
            "my-service",
            new ConsumerGroupLagQuery { TopicFilter = new[] { "my-events" } });
        return lag.TotalLag;
    }

    public async Task<TopicMetadata> GetTopicInfoAsync(CancellationToken ct)
    {
        return await _admin.GetTopicMetadataAsync("my-events");
    }
}
```

### Admin Client with Shared Kafka Configuration Profile

If the application already binds `KoreForge.Kafka.Configuration`, reuse the profile:

```csharp
var configFactory = services.BuildServiceProvider().GetRequiredService<IKafkaClientConfigFactory>();

var adminClient = KafkaAdminClientHost
    .Create()
    .UseKafkaConfigurationProfile("AdminPrimary", configFactory)
    .UseLoggerFactory(loggerFactory)
    .UseMetrics(metrics)         // optional: IOperationMonitor from KoreForge.Metrics
    .Build();
```

### Admin Client Metrics (Automatic)

When `IOperationMonitor` is registered (`AddKoreForgeMetrics()`), `AddKafkaAdminClient` auto-wires metrics:

- `kafka.admin.metadata` — broker metadata call duration + failures
- `kafka.admin.lag` — lag query duration + failures
- `kafka.admin.offsets-for-timestamp` — offset lookup duration
- `kafka.admin.errors` — per-operation errors tagged with exception type
- `kafka.admin.cache.hit` / `kafka.admin.cache.miss` — TTL cache hit/miss

To suppress the default metrics, register your own `IKafkaAdminMetrics` before calling `AddKafkaAdminClient`.

## Docker Dev Environment

```powershell
# Start Redpanda (Kafka-compatible) on localhost:29092
.\samples\docker\up.ps1

# Stop
.\samples\docker\down.ps1
```

## Checklist

- [ ] `KoreForge.Kafka` in `Directory.Packages.props` + `.csproj`
- [ ] `AddKafkaConfiguration(configuration.GetSection("Kafka"))` registered before producers/consumers
- [ ] Each producer/consumer specifies `ProfileName` matching a key under `Kafka:Profiles`
- [ ] Consumer `GroupId` is unique per logical consumer group
- [ ] `IKafkaMessageHandler<TKey, TValue>` implemented for each consumer
- [ ] Admin client registered with `AddKafkaAdminClient` if lag/metadata checks are needed
- [ ] If `IOperationMonitor` is registered, admin client metrics are wired automatically
