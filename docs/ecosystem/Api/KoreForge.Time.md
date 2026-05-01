# KoreForge.Time — API Reference

**Package**: `KoreForge.Time`  |  **Assembly**: `KF.Time.dll`  |  **Namespace**: `KF.Time`

---

## `ISystemClock` Interface

Abstracts the system clock for testable time-dependent code.

```csharp
namespace KF.Time;

public interface ISystemClock
{
    /// Current local time.
    DateTimeOffset Now { get; }

    /// Current UTC time.
    DateTimeOffset UtcNow { get; }

    /// High-resolution timestamp in Stopwatch ticks (matches Stopwatch.GetTimestamp() frequency).
    long TimestampTicks { get; }
}
```

---

## `LocalSystemClock` Class

Returns the machine's local time. Thread-safe singleton.

```csharp
namespace KF.Time;

public sealed class LocalSystemClock : ISystemClock
{
    /// Shared singleton instance.
    public static readonly LocalSystemClock Instance;

    public DateTimeOffset Now         { get; }  // DateTimeOffset.Now
    public DateTimeOffset UtcNow      { get; }  // DateTimeOffset.UtcNow
    public long           TimestampTicks { get; }
}
```

---

## `UtcSystemClock` Class

Returns UTC time. Thread-safe singleton.

```csharp
namespace KF.Time;

public sealed class UtcSystemClock : ISystemClock
{
    /// Shared singleton instance.
    public static readonly UtcSystemClock Instance;

    public DateTimeOffset Now         { get; }  // DateTimeOffset.UtcNow
    public DateTimeOffset UtcNow      { get; }  // DateTimeOffset.UtcNow
    public long           TimestampTicks { get; }
}
```

---

## `VirtualSystemClock` Class

A manually-controlled clock for deterministic unit testing. **Not thread-safe** — intended for single-threaded test use.

```csharp
namespace KF.Time;

public sealed class VirtualSystemClock : ISystemClock
{
    /// Initialise with a starting time.
    public VirtualSystemClock(DateTimeOffset startTime);

    /// Current (virtual) local time.
    public DateTimeOffset Now         { get; }

    /// Current (virtual) UTC time.
    public DateTimeOffset UtcNow      { get; }

    /// Virtual timestamp ticks, advanced proportionally with Advance().
    public long           TimestampTicks { get; }

    /// Advance the clock forward by the given duration.
    /// Throws ArgumentOutOfRangeException if duration is negative.
    public void Advance(TimeSpan duration);

    /// Set the clock to an absolute time.
    /// Throws ArgumentOutOfRangeException if newTime is before the current virtual time.
    public void Set(DateTimeOffset newTime);
}
```

### Exceptions

| Method | Exception | When |
|--------|-----------|------|
| `Advance(TimeSpan)` | `ArgumentOutOfRangeException` | `duration < TimeSpan.Zero` |
| `Set(DateTimeOffset)` | `ArgumentOutOfRangeException` | `newTime < current UtcNow` |

---

## `SystemClock` Static Class

A convenience static accessor.

```csharp
namespace KF.Time;

public static class SystemClock
{
    /// Current default instance. Defaults to LocalSystemClock.Instance.
    /// Can be replaced globally (e.g., in test bootstrapping).
    public static ISystemClock Instance { get; set; }
}
```

---

## Usage Examples

```csharp
// Production DI registration
builder.Services.AddSingleton<ISystemClock>(LocalSystemClock.Instance);

// UTC-only service
builder.Services.AddSingleton<ISystemClock>(UtcSystemClock.Instance);

// Test — deterministic time
var clock = new VirtualSystemClock(new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero));
clock.Advance(TimeSpan.FromHours(2));
Assert.Equal(2, clock.UtcNow.Hour);

// High-resolution duration measurement
long start = clock.TimestampTicks;
// ... work ...
long elapsed = clock.TimestampTicks - start;
double ms = elapsed * 1000.0 / Stopwatch.Frequency;
```
