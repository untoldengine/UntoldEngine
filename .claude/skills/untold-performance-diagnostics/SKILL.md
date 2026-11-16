---
name: untold-performance-diagnostics
description: Use when triaging frame-time, streaming, batching, memory, or draw-call problems in an Untold Engine app — enabling metrics/frame stats, reading streaming or batching diagnostics snapshots, spatial debug overlays (tile bounds, LOD levels, octree leaves), or targeted logger categories. Triggers on "why is this scene slow", "frame rate drops in this area", "draw calls are too high", "streaming stalls/evictions", "profile this scene". Not for one-off API usage questions about a specific system (use that system's own skill/doc), initial setup of a tiled streamed scene (see untold-geometry-streaming), setting up per-entity LOD levels in the first place (see untold-lod-system), or fixing the underlying engine code itself (engine-internal work).
version: 0.1.0
---

# Performance Diagnostics in Untold Engine

A practical triage path for large scenes: streaming, batching, LOD, texture streaming, and frame-time issues. Start with structured metrics; only enable subsystem logs once you need to zoom in on a specific symptom — leaving verbose logger categories on is noisy and itself costs perf.

## 1. Enable metrics and frame stats

```swift
setEngine(.metrics(.enabled))
```

or from the environment: `export UNTOLD_METRICS=1` before launch.

```swift
setEngineStatsLogging(enabled: true, profile: .compact, intervalSeconds: 1.0)
```

Switch to `.verbose` only when diagnosing streaming, batching, or memory behavior specifically — it's noisier:

```swift
setEngineStatsLogging(enabled: true, profile: .verbose, intervalSeconds: 1.0)
```

## 2. Read snapshots in code

```swift
let metrics = EngineProfiler.shared.snapshot()
print("CPU mean: \(metrics.cpuFrame.meanMs) ms")
print("GPU mean: \(metrics.gpuCommandBuffer.meanMs) ms")

let frameStats = getEngineStatsSnapshot()
print("Render: \(frameStats.timing.renderTotalMs) ms")
```

Use this for in-app HUDs, automated tests, or regression tracking rather than eyeballing console spam.

## 3. Spatial debug overlays

```swift
setSpatialDebug(.tileBounds(enabled: true))
setSpatialDebug(.lodLevels(true))
setSpatialDebug(.textureStreamingTiers(true))
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .residency
)))
```

Always disable when done: `setSpatialDebug(.disabled)`.

## 4. Streaming triage

Enable verbose stats first, then watch for:

| Symptom | Meaning |
| --- | --- |
| high `backlog` | load slots are saturated |
| high `avgLoadMs` | asset I/O or parsing is slow |
| high `applyMs` | GPU upload/application cost is expensive |
| frequent `evictions` | memory budget is too tight |
| high visible full-tile triangles far from camera | LOD switching is late |

```swift
let diag = GeometryStreamingSystem.shared.getDiagnosticsSnapshot()
print("workMs: \(diag.updateWorkMs), candidates: \(diag.loadCandidates)")
print("slots: \(diag.availableLoadSlots), evictions: \(diag.evictionsPerformed)")
```

Tuning knobs:

```swift
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.queryRadius(650.0))
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))
```

## 5. Static batching triage

If draw count is high relative to visible entity count:

```swift
setLogger(.category(.batching, true))
BatchingSystem.shared.logMaterialDiagnosticsNow()
setLogger(.category(.batching, false))
```

| Symptom | Likely cause |
| --- | --- |
| `staticBatch=0` | Entities were never marked with `StaticBatchComponent` |
| high `uniqueMatLOD` | Too much material diversity |
| `cellsBlocked > 0` | Batch cells too complex for the runtime guard |
| low `resolved` | Entities are transparent, animated, or identity-preserving |

For always-resident static content:

```swift
setEntityStaticBatchComponent(entityId: entity)
setBatching(.enabled(true))
generateBatches()
```

For tiled streaming scenes, **do not** call `generateBatches()` per tile — the engine updates streamed batching incrementally on its own.

## 6. Logger categories — enable narrowly, disable after capture

```swift
setLogger(.categories([
    .tileStreaming, .streamingHeartbeat, .oocStatus, .oocTiming, .assetLoader,
], true))
// reproduce the issue
setLogger(.categories([
    .tileStreaming, .streamingHeartbeat, .oocStatus, .oocTiming, .assetLoader,
], false))
```

Texture diagnostics: `setLogger(.categories([.textureStreaming, .textureLoading], true))`.

Light portal diagnostics:

```swift
setLogger(.category(.lightPortal, true))
LightPortalSystem.shared.logDiagnosticsNow()
setLogger(.category(.lightPortal, false))
```

## 7. Overall triage order

1. Enable metrics and compact frame stats.
2. If frame time is bad, switch to verbose stats.
3. Use spatial overlays to inspect tile bounds, LOD, and texture tiers.
4. If draw count is high, run batching diagnostics.
5. If loading stalls, inspect streaming diagnostics and logs.
6. If scene lighting from portals looks wrong, run light portal diagnostics (see `untold-scene-channels`).
7. Disable high-volume log categories once the repro is captured — don't leave them on.

Full reference: `docs/API/UsingProfiler.md`, `docs/API/UsingTheLogger.md`, `docs/API/SpatialDebugger.md`, `docs/API/UsingGeometryStreamingSystem.md`, `docs/API/UsingStaticBatchingSystem.md`.
