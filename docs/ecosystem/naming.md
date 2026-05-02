# Naming Standard

KoreForge uses the public name everywhere. The short `KoreForge.*` form is legacy only and should not be used for new folders, projects, assemblies, namespaces, packages, scripts, or documentation.

## KoreForge Assets

| Asset | Standard | Example |
| --- | --- | --- |
| Repository folder | `KoreForge.Area` | `KoreForge.Kafka` |
| Solution | `KoreForge.Area.slnx` | `KoreForge.Kafka.slnx` |
| Project folder | `KoreForge.Area.Component` | `KoreForge.Kafka.Consumer` |
| Project file | `KoreForge.Area.Component.csproj` | `KoreForge.Kafka.Consumer.csproj` |
| Assembly/DLL | `KoreForge.Area.Component` | `KoreForge.Kafka.Consumer.dll` |
| Namespace | `KoreForge.Area.Component` | `KoreForge.Kafka.Consumer.Hosting` |
| NuGet package | `KoreForge.Area.Component` | `KoreForge.Kafka.Consumer` |
| Test project | `KoreForge.Area.Component.Tests` | `KoreForge.Kafka.Consumer.Tests` |

## Event Assets

Event applications and Event-owned test libraries use `Event.*` everywhere. They are not KoreForge packages even when they prove KoreForge behavior.

Examples:

- `event/Event.Streaming`
- `event/Event.Reader`
- `Event.Streaming.In`
- `Event.Reader.Tests`

## Package Mapping

Default runtime packages have one primary package ID and one primary assembly with the same name.

Allowed exceptions:

- Meta-packages that carry only dependencies and may have no DLL.
- Analyzer/source-generator packages that place assemblies under analyzer/build assets.
- CLI/tool packages where the tool identity is the package identity.
- Template/content packages.

Grouped repos are expected. A repo such as `KoreForge.Kafka` can produce several packages, but each package still has a clear public project, namespace, assembly, and package identity.

## Dependencies

Projects do not use `ProjectReference`. Cross-repo and cross-project dependencies use `PackageReference`, including local development. The local feed is `artifacts/packages` and is listed before nuget.org in the workspace `NuGet.config`.

## Legacy Names

Existing `KoreForge.*` names are transitional debt. When touched for renovation, rename the project, assembly, namespace, package ID, and documentation together so mixed identity does not leak into new code.
