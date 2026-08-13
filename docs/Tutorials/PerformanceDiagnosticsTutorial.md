# Performance Diagnostics

This tutorial gives a practical triage path for large scenes, streaming,
batching, LOD, texture streaming, and frame-time issues.

Use structured metrics first. Enable subsystem logs only when you need detail.

## Enable Metrics

At runtime:

```swift
setEngine(.metrics(.enabled))
```

Or from the environment:

```bash
export UNTOLD_METRICS=1
./YourApp
```

Enable periodic frame stats:

```swift
setEngineStatsLogging(
    enabled: true,
    profile: .compact,
    intervalSeconds: 1.0
)
```

Use `.verbose` when diagnosing streaming, batching, or memory behavior:

```swift
setEngineStatsLogging(enabled: true, profile: .verbose, intervalSeconds: 1.0)
```

## Read Snapshots In Code

```swift
let metrics = EngineProfiler.shared.snapshot()
print("CPU mean: \(metrics.cpuFrame.meanMs) ms")
print("GPU mean: \(metrics.gpuCommandBuffer.meanMs) ms")

let frameStats = getEngineStatsSnapshot()
print("Frame: \(frameStats.frameIndex)")
print("Render: \(frameStats.timing.renderTotalMs) ms")
```

Use this for in-app HUDs, automated tests, or regression tracking.

## Spatial Debug Overlays

Use overlays to inspect what the engine is doing spatially:

```swift
setSpatialDebug(.tileBounds(enabled: true))
setSpatialDebug(.lodLevels(true))
setSpatialDebug(.textureStreamingTiers(true))
```

For octree leaf bounds:

```swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .residency
)))
```

Disable overlays when finished:

```swift
setSpatialDebug(.disabled)
```

## Streaming Triage

For streamed scenes, start with verbose stats. Look for:

- high `backlog`: load slots are saturated
- high `avgLoadMs`: asset I/O or parsing is slow
- high `applyMs`: GPU upload/application cost is expensive
- frequent `evictions`: memory budget is too tight
- high visible full-tile triangles far from camera: LOD switching may be late

Read streaming diagnostics programmatically:

```swift
let diag = GeometryStreamingSystem.shared.getDiagnosticsSnapshot()
print("workMs: \(diag.updateWorkMs)")
print("candidates: \(diag.loadCandidates)")
print("slots: \(diag.availableLoadSlots)")
print("evictions: \(diag.evictionsPerformed)")
```

Tune with:

```swift
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.queryRadius(650.0))
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))
```

## Static Batching Triage

If draw count is high relative to visible entities, inspect batching:

```swift
setLogger(.category(.batching, true))
BatchingSystem.shared.logMaterialDiagnosticsNow()
setLogger(.category(.batching, false))
```

Common patterns:

| Symptom | Likely Cause |
| --- | --- |
| `staticBatch=0` | Entities were never marked with `StaticBatchComponent`. |
| high `uniqueMatLOD` | Too much material diversity. |
| `cellsBlocked > 0` | Batch cells are too complex for the runtime guard. |
| low `resolved` | Entities are transparent, animated, or identity-preserving. |

For always-resident static content:

```swift
setEntityStaticBatchComponent(entityId: entity)
setBatching(.enabled(true))
generateBatches()
```

For tiled streaming scenes, do not call `generateBatches()` per tile. The engine
updates streamed batching incrementally.

## Logger Categories

Enable focused logs only while reproducing an issue:

```swift
setLogger(.categories([
    .tileStreaming,
    .streamingHeartbeat,
    .oocStatus,
    .oocTiming,
    .assetLoader,
], true))
```

Disable them after capture:

```swift
setLogger(.categories([
    .tileStreaming,
    .streamingHeartbeat,
    .oocStatus,
    .oocTiming,
    .assetLoader,
], false))
```

Texture diagnostics:

```swift
setLogger(.categories([.textureStreaming, .textureLoading], true))
```

Light portal diagnostics:

```swift
setLogger(.category(.lightPortal, true))
LightPortalSystem.shared.logDiagnosticsNow()
setLogger(.category(.lightPortal, false))
```

## Practical Triage Order

1. Enable metrics and compact frame stats.
2. If frame time is bad, switch to verbose stats.
3. Use spatial overlays to inspect tile bounds, LOD, and texture tiers.
4. If draw count is high, run batching diagnostics.
5. If loading stalls, inspect streaming diagnostics and logs.
6. If visual lighting from portals is wrong, run light portal diagnostics.
7. Disable high-volume log categories when finished.

## Related Documentation

- [Profiler](../API/UsingProfiler.md)
- [Logger](../API/UsingTheLogger.md)
- [Spatial Debugger](../API/SpatialDebugger.md)
- [Geometry Streaming](../API/UsingGeometryStreamingSystem.md)
- [Static Batching](../API/UsingStaticBatchingSystem.md)
