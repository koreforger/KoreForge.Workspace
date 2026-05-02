# KoreForge Monitoring Shell — Architecture & Design Specification

**Version:** 0.1  
**Date:** 2026-04-30  
**Status:** Design — not yet in implementation

---

## 1. Purpose

This document defines the architecture of a capability-driven, reusable monitoring front-end for KoreForge-based applications. The front-end is not an EventReader dashboard. It is an application-agnostic shell that connects to any KoreForge application, reads what that application exposes, and renders exactly that — no more, no less.

---

## 2. Guiding Principles

### 2.1 The shell does not know what EventReader is

The shell knows how to render:

```
Application
  -> Pipeline diagram with live throughput per node
  -> Registered capability panels (app-specific)
  -> Real-time metric stream
  -> Health summary
```

The application tells the shell what it supports. The shell renders it.

### 2.2 The pipeline view is the primary health signal

The pipeline diagram is the first screen. It answers the most important operational question at a glance:

- Is data flowing?
- Where is it backing up?
- Which node is the bottleneck?

Every other panel is secondary. Deep diagnostics, script editors, backlog state views — all accessed from the pipeline as entry points or as sidebar panels, not as the default view.

### 2.3 Capability panels are parameterised, not typed

An application can register the same component type more than once with different configuration. A JexScript editor panel is not "the script panel" — it is an instance bound to a specific script set and endpoint. Two instances can appear side-by-side in the same dashboard, each operating independently.

### 2.4 Unknown capabilities do not break the shell

If the shell receives a capability key it does not have a registered component for, it renders a generic metric card using the declared `metricsPrefix`. The dashboard degrades gracefully — it does not crash.

### 2.5 Contracts first

The backend and frontend contracts are the product. Neither the Vue components nor the C# controllers should be written until the contract DTOs are stable and agreed upon.

---

## 3. Repository and Package Structure

### 3.1 Backend (C#)

| Package | Responsibility |
|---|---|
| `KoreForge.Monitoring.Contracts` | Shared DTO record types (manifest, pipeline, metrics, capabilities). No dependencies. |
| `KoreForge.Monitoring.AspNetCore` | Controller base classes, endpoint registration, `IMonitoringManifestProvider`, `IPipelineDefinitionProvider`, `ICapabilityProvider`. |
| `KoreForge.Monitoring.SignalR` | SignalR hub, metric push service, delta projection. |
| `KoreForge.Monitoring.Metrics` | `IMonitoringMetricsCollector` implementations, metric naming conventions. |

Each application registers its monitoring by implementing providers:

```csharp
builder.Services
    .AddKoreForgeMonitoring()
    .WithApplication("EventReader", instanceId: "prod-01")
    .WithPipeline<EventReaderPipelineDefinitionProvider>()
    .WithMetrics<EventReaderMetricsProvider>()
    .WithCapability<DurableBacklogCapabilityProvider>()
    .WithCapability<JexScriptCapabilityProvider>("ingestScripts",  opts => opts.Endpoint = "/monitoring/scripts/ingest")
    .WithCapability<JexScriptCapabilityProvider>("outputScripts",  opts => opts.Endpoint = "/monitoring/scripts/output")
    .WithCapability<RuntimeModelCapabilityProvider>()
    .WithSignalR("/monitoring/hub");
```

The monitoring framework owns HTTP exposure. The application owns its data.

### 3.2 Frontend (TypeScript / Vue 3)

| Package / App | Responsibility |
|---|---|
| `KoreForge.Jex.Vue` | npm package. `JexScriptPanel`, `JexEditorPanel`, `JexTestPanel`. Reusable wherever Jex scripts are exposed. |
| `KoreForge.Kafka.Vue` | npm package. `KafkaConsumerPanel`, `KafkaLagPanel`. |
| `KoreForge.Monitoring.Shell` | The application. Composes all packages, renders pipeline, hosts capability panels. |
| `EventReader.Vue` | EventReader-specific Vue components not belonging to any reusable package. `DurableBacklogPanel`, `RuntimeModelPanel`, `ShardWorkerPanel`. |

The shell imports registered component packages. Capability keys declared by the backend manifest map to registered Vue components in the shell's component registry.

---

## 4. Backend API Contracts

All endpoints live under `/monitoring`.

### 4.1 Manifest

```
GET /monitoring/manifest
```

Returns the application identity, what capabilities it supports, and where to fetch them.

```json
{
  "applicationId": "eventreader-prod-01",
  "applicationName": "EventReader",
  "applicationType": "EventReader",
  "instanceId": "prod-01",
  "environment": "PROD",
  "version": "1.4.7",
  "monitoringContractVersion": "1.0",
  "capabilities": [
    {
      "key": "pipeline",
      "displayName": "Pipeline",
      "component": "PipelineDiagram",
      "endpoint": "/monitoring/pipeline"
    },
    {
      "key": "durableBacklog",
      "displayName": "Durable Backlog",
      "component": "DurableBacklogPanel",
      "endpoint": "/monitoring/durable-store"
    },
    {
      "key": "runtimeModel",
      "displayName": "Runtime Model",
      "component": "RuntimeModelPanel",
      "endpoint": "/monitoring/runtime-model"
    },
    {
      "key": "jexScripts.ingest",
      "displayName": "Ingest Scripts",
      "component": "JexScriptPanel",
      "endpoint": "/monitoring/scripts/ingest",
      "config": { "scriptSet": "IngestClassifier", "editable": true }
    },
    {
      "key": "jexScripts.output",
      "displayName": "Output Scripts",
      "component": "JexScriptPanel",
      "endpoint": "/monitoring/scripts/output",
      "config": { "scriptSet": "OutputTransformer", "editable": false }
    }
  ],
  "stream": "/monitoring/hub",
  "health": "/monitoring/health"
}
```

**C# record:**

```csharp
public sealed record MonitoringManifestDto(
    string ApplicationId,
    string ApplicationName,
    string ApplicationType,
    string InstanceId,
    string Environment,
    string Version,
    string MonitoringContractVersion,
    IReadOnlyList<CapabilityDefinitionDto> Capabilities,
    string Stream,
    string Health
);

public sealed record CapabilityDefinitionDto(
    string Key,
    string DisplayName,
    string Component,
    string Endpoint,
    IReadOnlyDictionary<string, object>? Config = null
);
```

### 4.2 Pipeline Definition

```
GET /monitoring/pipeline
```

Returns the processing pipeline as a graph of nodes and edges. This is the data model behind the pipeline diagram.

```json
{
  "pipelineId": "eventreader-main",
  "name": "EventReader Message Processing Pipeline",
  "version": "2026.04.30.001",
  "nodes": [
    {
      "id": "kafka-consumer",
      "label": "Kafka Consumer",
      "type": "source",
      "componentKey": "kafkaConsumer",
      "metricsPrefix": "eventreader.kafkaConsumer",
      "statusMetric": "eventreader.kafkaConsumer.status",
      "positionHint": { "group": "ingest", "order": 10 }
    },
    {
      "id": "classifier",
      "label": "Batch Classifier",
      "type": "processor",
      "componentKey": "classifier",
      "metricsPrefix": "eventreader.classifier",
      "positionHint": { "group": "ingest", "order": 20 }
    },
    {
      "id": "durable-store",
      "label": "Durable Work Store",
      "type": "queue",
      "componentKey": "durableStore",
      "metricsPrefix": "eventreader.durableStore",
      "positionHint": { "group": "durable", "order": 30 }
    },
    {
      "id": "shard-workers",
      "label": "Shard Workers",
      "type": "workerPool",
      "componentKey": "shardWorkers",
      "metricsPrefix": "eventreader.shardWorkers",
      "positionHint": { "group": "processing", "order": 40 }
    },
    {
      "id": "work-item-processor",
      "label": "Work Item Processor",
      "type": "processor",
      "componentKey": "workItemProcessor",
      "metricsPrefix": "eventreader.workItemProcessor",
      "positionHint": { "group": "processing", "order": 50 }
    },
    {
      "id": "output-publisher",
      "label": "Output Publisher",
      "type": "publisher",
      "componentKey": "outputPublisher",
      "metricsPrefix": "eventreader.outputPublisher",
      "positionHint": { "group": "output", "order": 60 }
    },
    {
      "id": "output-topic",
      "label": "Output Kafka Topic",
      "type": "sink",
      "componentKey": "outputTopic",
      "metricsPrefix": "eventreader.outputTopic",
      "positionHint": { "group": "output", "order": 70 }
    }
  ],
  "edges": [
    { "id": "e1", "from": "kafka-consumer",    "to": "classifier",          "label": "Kafka batch" },
    { "id": "e2", "from": "classifier",         "to": "durable-store",       "label": "Classified work item" },
    { "id": "e3", "from": "durable-store",      "to": "shard-workers",       "label": "Leased shard batch" },
    { "id": "e4", "from": "shard-workers",      "to": "work-item-processor", "label": "Work item" },
    { "id": "e5", "from": "work-item-processor","to": "output-publisher",    "label": "ReadyToOutput" },
    { "id": "e6", "from": "output-publisher",   "to": "output-topic",        "label": "Published message" }
  ]
}
```

**C# records:**

```csharp
public sealed record PipelineDefinitionDto(
    string PipelineId,
    string Name,
    string Version,
    IReadOnlyList<PipelineNodeDto> Nodes,
    IReadOnlyList<PipelineEdgeDto> Edges
);

public sealed record PipelineNodeDto(
    string Id,
    string Label,
    string Type,           // source | processor | queue | workerPool | publisher | sink
    string ComponentKey,
    string MetricsPrefix,
    string? StatusMetric,
    PipelinePositionHintDto? PositionHint
);

public sealed record PipelineEdgeDto(
    string Id,
    string From,
    string To,
    string? Label
);

public sealed record PipelinePositionHintDto(
    string Group,
    int Order
);
```

**Node types:**

| Type | Meaning | Visual |
|---|---|---|
| `source` | Data origin (Kafka consumer) | Rounded rectangle, input arrow |
| `processor` | Transform / classify | Rectangle |
| `queue` | Durable or in-memory buffer | Cylinder |
| `workerPool` | Parallel workers | Stacked rectangles |
| `publisher` | Outbound writer | Rectangle with output arrow |
| `sink` | Terminal destination (Kafka topic, DB) | Rounded rectangle, output arrow |

### 4.3 Metrics Snapshot

```
GET /monitoring/metrics/snapshot
```

Flat metric stream. Every metric declares the `componentKey` it belongs to, linking it to a pipeline node.

```json
{
  "timestampUtc": "2026-04-30T12:45:00Z",
  "applicationId": "eventreader-prod-01",
  "metrics": [
    {
      "key": "eventreader.kafkaConsumer.records.ratePerSecond",
      "label": "Ingest Rate",
      "kind": "gauge",
      "value": 8420,
      "unit": "records/sec",
      "componentKey": "kafkaConsumer"
    },
    {
      "key": "eventreader.classifier.records.total",
      "label": "Total Classified",
      "kind": "counter",
      "value": 128832001,
      "unit": "records",
      "componentKey": "classifier"
    },
    {
      "key": "eventreader.classifier.unclassifiedRatio",
      "label": "Unclassified Ratio",
      "kind": "gauge",
      "value": 0.034,
      "unit": "ratio",
      "componentKey": "classifier"
    },
    {
      "key": "eventreader.durableStore.backlog.classified",
      "label": "Classified Backlog",
      "kind": "gauge",
      "value": 84211,
      "unit": "items",
      "componentKey": "durableStore"
    },
    {
      "key": "eventreader.durableStore.backlog.retryPending",
      "label": "Retry Pending",
      "kind": "gauge",
      "value": 312,
      "unit": "items",
      "componentKey": "durableStore"
    },
    {
      "key": "eventreader.shardWorkers.activeWorkers",
      "label": "Active Workers",
      "kind": "gauge",
      "value": 8,
      "unit": "workers",
      "componentKey": "shardWorkers"
    },
    {
      "key": "eventreader.outputPublisher.publishLatency.p95",
      "label": "Publish Latency P95",
      "kind": "histogramPercentile",
      "value": 42,
      "unit": "ms",
      "componentKey": "outputPublisher"
    }
  ]
}
```

**C# records:**

```csharp
public sealed record MetricSnapshotDto(
    DateTimeOffset TimestampUtc,
    string ApplicationId,
    IReadOnlyList<MetricValueDto> Metrics
);

public sealed record MetricValueDto(
    string Key,
    string Label,
    MetricKind Kind,
    double Value,
    string Unit,
    string ComponentKey
);

public enum MetricKind
{
    Counter,
    Gauge,
    Rate,
    HistogramPercentile
}
```

### 4.4 Health Snapshot

```
GET /monitoring/health
```

```json
{
  "status": "Healthy",
  "checks": [
    { "name": "KafkaConsumer",  "status": "Healthy",   "description": "Consumer running, lag 421" },
    { "name": "DurableStore",   "status": "Healthy",   "description": "Disk free 48GB" },
    { "name": "ShardWorkers",   "status": "Healthy",   "description": "8/8 workers active" },
    { "name": "OutputPublisher","status": "Degraded",  "description": "Publish latency P95 elevated (420ms)" },
    { "name": "RuntimeModel",   "status": "Healthy",   "description": "Model v42 loaded" }
  ]
}
```

---

## 5. Real-Time Stream (SignalR)

Hub endpoint: `/monitoring/hub`

### 5.1 Connection sequence

```
1. UI connects to app
2. UI fetches /monitoring/manifest
3. UI fetches /monitoring/pipeline
4. UI fetches /monitoring/metrics/snapshot  (initial full state)
5. UI opens SignalR connection to /monitoring/hub
6. Hub pushes MetricDelta messages (1–5 second cadence)
7. UI applies deltas to local metric store
8. Every 60 seconds, UI refreshes full snapshot to correct drift
```

### 5.2 MetricDelta message

```json
{
  "messageType": "MetricDelta",
  "timestampUtc": "2026-04-30T12:46:03Z",
  "applicationId": "eventreader-prod-01",
  "sequence": 981273,
  "metrics": [
    { "key": "eventreader.kafkaConsumer.records.ratePerSecond", "value": 8532 },
    { "key": "eventreader.durableStore.backlog.classified",     "value": 83110 },
    { "key": "eventreader.outputPublisher.publishLatency.p95",  "value": 38 }
  ]
}
```

Only changed values are sent in a delta. Full `key` from snapshot identifies each metric. UI merges by key.

### 5.3 HealthChanged message

```json
{
  "messageType": "HealthChanged",
  "timestampUtc": "2026-04-30T12:46:10Z",
  "applicationId": "eventreader-prod-01",
  "overallStatus": "Degraded",
  "changed": [
    { "name": "OutputPublisher", "status": "Degraded", "description": "Publish latency P95 elevated (420ms)" }
  ]
}
```

---

## 6. Frontend Architecture

### 6.1 Shell structure

```
KoreForge.Monitoring.Shell/
  src/
    App.vue                         # Root layout, app selector, connection state
    main.ts                         # Bootstrap, plugin registration
    router/
      index.ts                      # Routes: /, /app/:appId, /app/:appId/pipeline, ...
    stores/
      appStore.ts                   # Active application, connection state
      manifestStore.ts              # Manifest + capabilities for active app
      pipelineStore.ts              # Pipeline definition (nodes, edges)
      metricStore.ts                # Live metric values, keyed by metric key
      healthStore.ts                # Health check state
    services/
      MonitoringApiService.ts       # HTTP client for manifest, pipeline, snapshot
      SignalRMetricStream.ts        # SignalR connection, delta application
      CapabilityLoader.ts           # Resolves capability key -> Vue component
    components/
      shell/
        AppSelector.vue             # Pick app from registered list
        ConnectionBanner.vue        # Connection state indicator
        CapabilityNav.vue           # Sidebar nav built from manifest.capabilities
      pipeline/
        PipelineDiagram.vue         # Vue Flow graph renderer
        PipelineNode.vue            # Node template (type-driven visual)
        PipelineEdge.vue            # Edge template
        NodeMetricOverlay.vue       # Live rate/backlog badges on nodes
      panels/
        CapabilityPanelHost.vue     # Renders registered component for capability key
        GenericMetricPanel.vue      # Fallback for unknown capability keys
        HealthPanel.vue             # Health check summary
    registry/
      componentRegistry.ts          # Capability key -> Vue component map
      index.ts                      # Registers built-in + imported package components
```

### 6.2 Component registry

```typescript
// registry/componentRegistry.ts

import type { Component } from 'vue'

const registry = new Map<string, Component>()

export function registerComponent(key: string, component: Component): void {
  registry.set(key, component)
}

export function resolveComponent(key: string): Component {
  // Exact key match first
  if (registry.has(key)) return registry.get(key)!

  // Prefix match — "jexScripts.ingest" resolves to "jexScripts" component
  const prefix = key.split('.')[0]
  if (registry.has(prefix)) return registry.get(prefix)!

  // Fallback
  return registry.get('__generic')!
}
```

```typescript
// registry/index.ts

import { registerComponent } from './componentRegistry'
import GenericMetricPanel       from '@/components/panels/GenericMetricPanel.vue'
import PipelineDiagram          from '@/components/pipeline/PipelineDiagram.vue'
import HealthPanel              from '@/components/panels/HealthPanel.vue'

// KoreForge.Jex.Vue package
import { JexScriptPanel, JexEditorPanel } from '@koreforge/jex-vue'

// KoreForge.Kafka.Vue package
import { KafkaConsumerPanel } from '@koreforge/kafka-vue'

// EventReader-specific
import DurableBacklogPanel   from '@/components/eventreader/DurableBacklogPanel.vue'
import RuntimeModelPanel     from '@/components/eventreader/RuntimeModelPanel.vue'

export function registerAllComponents(): void {
  registerComponent('__generic',       GenericMetricPanel)
  registerComponent('pipeline',        PipelineDiagram)
  registerComponent('health',          HealthPanel)
  registerComponent('jexScripts',      JexScriptPanel)
  registerComponent('jexEditor',       JexEditorPanel)
  registerComponent('kafkaConsumer',   KafkaConsumerPanel)
  registerComponent('durableBacklog',  DurableBacklogPanel)
  registerComponent('runtimeModel',    RuntimeModelPanel)
}
```

### 6.3 CapabilityPanelHost

The host resolves and renders the correct component for each capability entry in the manifest:

```vue
<!-- CapabilityPanelHost.vue -->
<template>
  <component
    :is="resolvedComponent"
    :capability="capability"
    :metrics="capabilityMetrics"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { resolveComponent } from '@/registry/componentRegistry'
import { useMetricStore }   from '@/stores/metricStore'
import type { CapabilityDefinitionDto } from '@/contracts/monitoring'

const props = defineProps<{ capability: CapabilityDefinitionDto }>()

const metricStore = useMetricStore()

const resolvedComponent = computed(() =>
  resolveComponent(props.capability.component)
)

const capabilityMetrics = computed(() =>
  metricStore.metricsForComponent(props.capability.key)
)
</script>
```

### 6.4 Pipeline diagram

Use **Vue Flow** (`@vue-flow/core`) as the graph renderer. It supports:
- Typed custom node components
- Edge labels
- Dynamic layout updates
- Zoom / pan
- Programmatic node selection

The pipeline view overlays live metric values on nodes. Each node shows:
- **Inbound rate** (records/sec arriving)
- **Outbound rate** (records/sec leaving)
- **Backlog** (items buffered at this node, if queue type)
- **Status indicator** (green / amber / red driven by `statusMetric`)

```typescript
// pipelineStore.ts — metric binding to nodes

function enrichedNodes(nodes: PipelineNodeDto[], metrics: Map<string, number>) {
  return nodes.map(node => ({
    ...node,
    data: {
      inboundRate:  metrics.get(`${node.metricsPrefix}.records.inboundRate`)  ?? 0,
      outboundRate: metrics.get(`${node.metricsPrefix}.records.outboundRate`) ?? 0,
      backlog:      metrics.get(`${node.metricsPrefix}.backlog`)              ?? null,
      status:       metrics.get(node.statusMetric ?? '') === 1 ? 'healthy' : 'degraded'
    }
  }))
}
```

### 6.5 Pinia stores

```typescript
// metricStore.ts (outline)

export const useMetricStore = defineStore('metrics', {
  state: () => ({
    values: new Map<string, number>(),        // key -> current value
    definitions: new Map<string, MetricValueDto>()  // key -> full definition
  }),
  actions: {
    applySnapshot(snapshot: MetricSnapshotDto) {
      for (const m of snapshot.metrics) {
        this.values.set(m.key, m.value)
        this.definitions.set(m.key, m)
      }
    },
    applyDelta(delta: MetricDeltaDto) {
      for (const m of delta.metrics) {
        this.values.set(m.key, m.value)
      }
    }
  },
  getters: {
    metricsForComponent: (state) => (componentKey: string) =>
      [...state.definitions.values()]
        .filter(m => m.componentKey === componentKey)
        .map(m => ({ ...m, value: state.values.get(m.key) ?? 0 }))
  }
})
```

---

## 7. EventReader-Specific Capability Panels

These panels are declared by EventReader's backend and rendered by the shell when the matching capability key is present in the manifest.

### 7.1 DurableBacklogPanel

Shows work item state distribution in the FASTER KV store.

| State | Meaning |
|---|---|
| `Classified` | Received and matched, awaiting lease |
| `RetryPending` | Processing failed, queued for retry |
| `ReadyToOutput` | Processing complete, awaiting publish |
| `Completed` | Successfully published, retained for TTL |
| `Failed` | Exceeded retry budget, dead-lettered |

Backend endpoint: `GET /monitoring/durable-store`

```json
{
  "states": {
    "Classified":    84211,
    "RetryPending":  312,
    "ReadyToOutput": 1047,
    "Completed":     4829341,
    "Failed":        23
  },
  "oldestUnfinishedAgeSeconds": 312.4,
  "diskUsageBytes": 1073741824,
  "diskFreeBytes": 51539607552
}
```

Rendered as a horizontal stacked bar (DevExtreme chart) + summary metrics.

### 7.2 RuntimeModelPanel

Shows the current Jex runtime model version loaded, when it was loaded, and which profiles are active.

Backend endpoint: `GET /monitoring/runtime-model`

```json
{
  "modelVersion": 42,
  "loadedAtUtc": "2026-04-30T11:03:00Z",
  "profileCount": 7,
  "profiles": [
    { "name": "IngestClassifier", "scriptCount": 3, "active": true },
    { "name": "OutputTransformer", "scriptCount": 2, "active": true }
  ]
}
```

### 7.3 JexScriptPanel (from KoreForge.Jex.Vue)

Reusable panel for any application that uses Jex. Configured via the capability's `config` object:

```json
{
  "key": "jexScripts.ingest",
  "component": "JexScriptPanel",
  "endpoint": "/monitoring/scripts/ingest",
  "config": {
    "scriptSet": "IngestClassifier",
    "editable": true,
    "testable": true,
    "shadowTestEndpoint": "/monitoring/shadow-test/ingest"
  }
}
```

The panel uses the endpoint to:
- List all scripts in the set (GET `{endpoint}/list`)
- Load a script (GET `{endpoint}/{id}`)
- Save a script (PUT `{endpoint}/{id}`)
- Run a shadow test (POST `{shadowTestEndpoint}`)

This is completely decoupled from EventReader. Any KoreForge application that exposes a compatible Jex script endpoint can use this panel.

### 7.4 ShardWorkerPanel

Shows per-shard worker state.

Backend endpoint: `GET /monitoring/shard-workers`

```json
{
  "workerCount": 8,
  "logicalShardCount": 32,
  "workers": [
    { "id": 0, "shards": [0, 4, 8, 12], "active": true, "currentBatchSize": 250, "processingRatePerSecond": 1200 },
    { "id": 1, "shards": [1, 5, 9, 13], "active": true, "currentBatchSize": 248, "processingRatePerSecond": 1180 }
  ]
}
```

---

## 8. KoreForge.Jex.Vue Package Design

### 8.1 Components exported

```typescript
export { JexScriptPanel }   // list, view, save scripts
export { JexEditorPanel }   // full-screen Monaco editor for a single script
export { JexTestPanel }     // shadow test execution and result view
export { JexResultViewer }  // renders a JexTestResult (reusable)
```

### 8.2 Props contract (JexScriptPanel)

```typescript
interface JexScriptPanelProps {
  endpoint: string          // base endpoint for script CRUD
  scriptSet: string         // display name for the script set
  editable?: boolean        // show save button, default false
  testable?: boolean        // show test panel, default false
  shadowTestEndpoint?: string
}
```

The component is self-contained — it fetches its own data from `endpoint`. It does not receive scripts as props.

### 8.3 Events emitted

```typescript
emit('scriptSaved',  { id: string, version: number })
emit('testStarted',  { sessionId: string })
emit('testComplete', { sessionId: string, result: JexTestResult })
```

---

## 9. Backend Implementation Notes for EventReader

EventReader already has:
- `EventReaderMonitoringController` at `GET /api/eventreader/metrics` and `GET /api/eventreader/status`
- `EventReaderMonitoringSnapshot` with `KafkaMetrics`, `PipelineMetrics`, `SettingsSyncMetrics`
- `Hubs/Hubs.cs` (SignalR hub)
- `FunctionEndpoints.cs`, `FunctionScriptRepository.cs` (Jex script CRUD)

The monitoring library will add a standard façade in front of these, mapping the existing fields to the contract DTOs. It will not replace them — the existing endpoints remain for backward compatibility.

New endpoints to add (implementing the contracts above):

```
GET  /monitoring/manifest
GET  /monitoring/pipeline
GET  /monitoring/metrics/snapshot
GET  /monitoring/health
GET  /monitoring/durable-store
GET  /monitoring/runtime-model
GET  /monitoring/shard-workers
GET  /monitoring/scripts/ingest
GET  /monitoring/scripts/output
WS   /monitoring/hub
```

---

## 10. Contract DTOs — Complete TypeScript Interface List

```typescript
// contracts/monitoring.ts

export interface MonitoringManifestDto {
  applicationId: string
  applicationName: string
  applicationType: string
  instanceId: string
  environment: string
  version: string
  monitoringContractVersion: string
  capabilities: CapabilityDefinitionDto[]
  stream: string
  health: string
}

export interface CapabilityDefinitionDto {
  key: string
  displayName: string
  component: string
  endpoint: string
  config?: Record<string, unknown>
}

export interface PipelineDefinitionDto {
  pipelineId: string
  name: string
  version: string
  nodes: PipelineNodeDto[]
  edges: PipelineEdgeDto[]
}

export interface PipelineNodeDto {
  id: string
  label: string
  type: 'source' | 'processor' | 'queue' | 'workerPool' | 'publisher' | 'sink'
  componentKey: string
  metricsPrefix: string
  statusMetric?: string
  positionHint?: { group: string; order: number }
}

export interface PipelineEdgeDto {
  id: string
  from: string
  to: string
  label?: string
}

export interface MetricSnapshotDto {
  timestampUtc: string
  applicationId: string
  metrics: MetricValueDto[]
}

export interface MetricValueDto {
  key: string
  label: string
  kind: 'counter' | 'gauge' | 'rate' | 'histogramPercentile'
  value: number
  unit: string
  componentKey: string
}

export interface MetricDeltaDto {
  messageType: 'MetricDelta'
  timestampUtc: string
  applicationId: string
  sequence: number
  metrics: Array<{ key: string; value: number }>
}

export interface HealthSnapshotDto {
  status: 'Healthy' | 'Degraded' | 'Unhealthy' | 'Unknown'
  checks: HealthCheckDto[]
}

export interface HealthCheckDto {
  name: string
  status: 'Healthy' | 'Degraded' | 'Unhealthy'
  description: string
}

export interface HealthChangedDto {
  messageType: 'HealthChanged'
  timestampUtc: string
  applicationId: string
  overallStatus: string
  changed: HealthCheckDto[]
}
```

---

## 11. Build and Implementation Sequence

### Phase 1: Contracts (backend + frontend, no UI yet)

1. Create `KoreForge.Monitoring.Contracts` C# project. Define all record types.
2. Create `contracts/monitoring.ts` in the frontend. Mirror all C# types.
3. Review contracts. Freeze.

### Phase 2: Backend monitoring endpoints

4. Create `KoreForge.Monitoring.AspNetCore`. Implement manifest, pipeline, health endpoints.
5. Add EventReader monitoring providers. Wire `GET /monitoring/pipeline` and `GET /monitoring/manifest`.
6. Stub metrics snapshot — return existing `EventReaderMonitoringSnapshot` mapped to `MetricSnapshotDto`.
7. Wire SignalR hub at `/monitoring/hub` (reuse existing hub or create new one in contracts format).

### Phase 3: Shell skeleton

8. Scaffold `KoreForge.Monitoring.Shell` (Vue 3, Vite, TypeScript, Pinia, Vue Router).
9. Implement `MonitoringApiService` — fetch manifest, pipeline, snapshot.
10. Implement `metricStore` and `pipelineStore`.
11. Render pipeline diagram using Vue Flow with static nodes (no live data yet).

### Phase 4: Live metrics

12. Implement `SignalRMetricStream`. Apply deltas to `metricStore`.
13. Bind node metric overlays to live values.
14. Add snapshot refresh timer (60s).

### Phase 5: Capability panels

15. Implement `CapabilityPanelHost`. Build `GenericMetricPanel` fallback.
16. Implement `DurableBacklogPanel` and `RuntimeModelPanel` for EventReader.
17. Implement `JexScriptPanel` and `JexEditorPanel` in `KoreForge.Jex.Vue`.
18. Register all components. Connect backend endpoints.

### Phase 6: Polish and ops

19. `AppSelector` — configure multiple app endpoints, persist in local storage.
20. `ConnectionBanner` — reconnect on drop.
21. Error states for every panel.
22. Mobile-responsive layout.

---

## 12. Key Design Decisions and Rationale

| Decision | Rationale |
|---|---|
| Manifest-driven rendering | Shell never hardcodes app types. Unknown apps get generic panels. |
| Parameterised component instances | Same Jex panel type used twice with different configs; avoids duplicating components per script set. |
| metricsPrefix links nodes to metrics | Clean separation: pipeline topology is static; metrics are live. Prefix joins them without coupling. |
| Flat metric key space | Easy to store, diff, and delta-push. No nested structure to traverse at render time. |
| Vue Flow for pipeline | Native graph model (nodes + edges), supports dynamic updates, far less code than custom SVG. |
| Build-time component registry | Simpler than runtime plugin loading. Unknown keys get generic card. Ships in one bundle. |
| SignalR over polling | Already in use for shadow test results. Consistent approach. Lower latency than polling for live rates. |
| Snapshot + delta hybrid | Snapshot on connect ensures consistent initial state. Deltas keep it fresh. Periodic re-snapshot corrects drift. |
| KoreForge.Jex.Vue as npm package | Script editor is reusable beyond EventReader. Any app can register `JexScriptPanel` via its manifest. |
